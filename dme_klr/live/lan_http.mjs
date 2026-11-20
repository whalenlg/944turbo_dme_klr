// ============================================================
//  lan_http.mjs — HTTP requests to a regression host on the LAN
//
//  Used by remote_test.mjs (start, poll, fetch logs, stop a job) and
//  runall.mjs (the RUN REGRESSIONS host check).
//
//  A Mac with both wired and Wi-Fi up has two addresses on the host's
//  subnet. With one of them (192.168.1.21), most new connections to a
//  host (192.168.1.41) got no answer, while every one from the other
//  (192.168.1.8) went through. So a request whose connection isn't
//  answered in CONNECT_MS is sent again from this machine's next address
//  on that subnet, and the address that last worked is tried first.
//  Even from one address, a host's bridge (192.168.1.41:8951) left about
//  half of the new connections unanswered while other ports there took
//  every one, so a request is tried TRIES times in all, each a fresh
//  connection. A connection that's refused or answered is never sent
//  again: the host is there, and a POST may have reached it.
// ============================================================

import { request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import { networkInterfaces } from 'node:os';

export const CONNECT_MS = +process.env.DMEKLR_REMOTE_CONNECT_MS || 5_000;
const TRIES = 4;

// errors that mean the connection was never made (nothing was sent)
const NO_CONNECTION = new Set(['ECONNECT_TIMEOUT', 'ETIMEDOUT', 'EHOSTUNREACH', 'EHOSTDOWN', 'ENETUNREACH', 'EADDRNOTAVAIL']);

const ip4 = a => a.split('.').reduce((v, x) => v * 256 + +x, 0);

// This machine's IPv4 addresses on <hostname>'s subnet, when there are
// two or more and the host is given by IPv4 address. [] otherwise: the OS
// picks.
export function sourceAddresses(hostname) {
  if (!/^\d+\.\d+\.\d+\.\d+$/.test(hostname)) return [];
  const out = [];
  for (const list of Object.values(networkInterfaces()))
    for (const i of list ?? []) {
      if (i.family !== 'IPv4' || i.internal || !i.netmask) continue;
      const m = ip4(i.netmask);
      if (m && ((ip4(i.address) & m) >>> 0) === ((ip4(hostname) & m) >>> 0) && !out.includes(i.address)) out.push(i.address);
    }
  return out.length > 1 ? out : [];
}

const preferred = new Map();   // hostname → the source address that last worked
// the addresses to try for <hostname>, the one that last worked first
export function sourceOrder(hostname) {
  const all = sourceAddresses(hostname);
  const p = preferred.get(hostname);
  return p && all.includes(p) ? [p, ...all.filter(a => a !== p)] : all;
}
export const worked = (hostname, addr) => { if (addr) preferred.set(hostname, addr); };

// One request on a connection of its own (no keep-alive), from
// <localAddress> if given. Rejects with code ECONNECT_TIMEOUT when the
// connection isn't answered in connectMs, and when the whole request
// takes longer than timeoutMs. {status, ok, headers, body (Buffer)}.
export function lanRequestOnce(url, { method = 'GET', headers = {}, body, timeoutMs = 30_000, connectMs = CONNECT_MS, localAddress } = {}) {
  return new Promise((res, rej) => {
    const u = new URL(url);
    const data = body == null ? null : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
    const h = { ...headers, Connection: 'close', ...(data ? { 'Content-Length': data.length } : {}) };
    if (data && !Object.keys(h).some(k => k.toLowerCase() === 'content-type')) h['Content-Type'] = 'application/json';
    const req = (u.protocol === 'https:' ? httpsRequest : httpRequest)(u, { method, headers: h, agent: false, ...(localAddress ? { localAddress } : {}) }, r => {
      const parts = [];
      r.on('data', d => parts.push(d));
      r.on('end', () => {
        clearTimeout(all);
        const b = Buffer.concat(parts);
        res({ status: r.statusCode, ok: r.statusCode >= 200 && r.statusCode < 300, headers: r.headers, body: b,
              text: async () => b.toString('utf8'), json: async () => JSON.parse(b.toString('utf8')) });
      });
      r.on('error', rej);
    });
    const fail = (code, msg) => { const e = new Error(msg); e.code = code; req.destroy(e); };
    const conn = setTimeout(() => fail('ECONNECT_TIMEOUT', `no answer to connect in ${connectMs / 1000} s${localAddress ? ` from ${localAddress}` : ''}`), connectMs);
    const all = setTimeout(() => fail('ETIMEOUT', `no reply in ${timeoutMs / 1000} s`), timeoutMs);
    req.on('socket', s => { if (!s.connecting) clearTimeout(conn); else s.once('connect', () => clearTimeout(conn)); });
    req.on('close', () => clearTimeout(conn));
    req.on('error', e => { clearTimeout(conn); clearTimeout(all); rej(e); });
    if (data) req.write(data);
    req.end();
  });
}

// lanRequestOnce up to opts.tries (TRIES) times while the connection
// isn't answered, from each of this machine's addresses on the host's
// subnet in turn; then the last error.
export async function lanRequest(url, opts = {}) {
  const host = new URL(url).hostname;
  const tries = opts.tries ?? TRIES;
  let last;
  for (let i = 0; i < tries; i++) {
    const srcs = sourceOrder(host);
    const localAddress = srcs.length ? srcs[i % srcs.length] : undefined;
    try {
      const r = await lanRequestOnce(url, { ...opts, localAddress });
      worked(host, localAddress);
      return r;
    } catch (e) {
      last = e;
      if (!NO_CONNECTION.has(e.code)) throw e;
      if (i + 1 < tries) await new Promise(r => setTimeout(r, 300));
    }
  }
  throw last;
}
