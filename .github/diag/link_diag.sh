#!/usr/bin/env bash
# Temporary: why verilated.o fails to link on MSYS2 (removed before merge)
set -x
log=../tmp/install_smoke/warm_idle_5s.log
grep -n 'verilated.cpp\|verilated_timing.cpp' "$log" | cut -c1-600 | head -5
obj=../tmp/dme_klr/verilator_obj/obj_warm_idle_5s
nm -C "$obj/verilated.o" | grep 'basic_string(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&)' | head
grep -n 'OPT_GLOBAL\|^CXX\b\|^CXX \|CXXFLAGS\|^LINK' /ucrt64/share/verilator/include/verilated.mk | head -30
inc=$(ls -d /ucrt64/include/c++/*/ | head -1)
grep -n '_GLIBCXX_EXTERN_TEMPLATE' "$inc"x86_64-w64-mingw32/bits/c++config.h | head
grep -n 'extern template class basic_string<char>' -B6 "$inc"bits/basic_string.tcc | head -20
grep -n 'basic_string(basic_string&& __str)' -B4 "$inc"bits/basic_string.h | head -12
cd "$(mktemp -d)"
printf '#include <string>\n#include <utility>\nstd::string g(std::string s);\nstd::string f(std::string&& s) { return g(std::move(s)); }\nstd::string g(std::string s) { return s; }\nint main() { std::string a(40, (char)97); return (int)f(std::move(a)).size() - 40; }\n' > t.cpp
for o in "-Os" "-O2" "-Os -std=gnu++17" "-Os -std=gnu++20" "-Os -fcoroutines"; do
  echo "== g++ $o"; g++ $o t.cpp -o t && ./t && echo OK
done
g++ -Os -c t.cpp && nm -C t.o | grep 'basic_string(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&)'
nm -C /ucrt64/lib/libstdc++.a 2>/dev/null | grep -c 'basic_string(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&)'
