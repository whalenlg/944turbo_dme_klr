#!/usr/bin/env bash
# Temporary (removed before merge): MSYS2 gcc 16 std::string move-ctor link bug
inc=$(ls -d /ucrt64/include/c++/*/ | head -1)
g++ --version | head -1
sed -n '280,296p;605,620p' "${inc}x86_64-w64-mingw32/bits/c++config.h"
grep -n '_GLIBCXX20_CONSTEXPR' "${inc}x86_64-w64-mingw32/bits/c++config.h" | head -3
cd "$(mktemp -d)"
cat > t.cpp <<'CPP'
#include <string>
#include <utility>
std::string g(std::string s);
std::string f(std::string&& s) { return g(std::move(s)); }
__attribute__((noinline)) std::string g(std::string s) { return s; }
int main() { std::string a(40, 'a'); return (int)f(std::move(a)).size() - 40; }
CPP
cat > fix.cpp <<'CPP'
#include <string>
template std::string::basic_string(std::string&&) noexcept;
CPP
try() { echo "== $*"; if "$@" 2>err.txt; then ./t && echo OK; else grep -m2 -E 'undefined|error' err.txt; fi; }
try g++ -Os t.cpp -o t
try g++ -O2 t.cpp -o t
try g++ -O0 t.cpp -o t
try g++ -O2 -fno-inline t.cpp -o t
try g++ -Os -fkeep-inline-functions t.cpp -o t
try g++ -Os t.cpp fix.cpp -o t
try g++ -Os -D_GLIBCXX_EXTERN_TEMPLATE=0 t.cpp -o t
try g++ -Os -fno-implicit-constexpr t.cpp -o t
try g++ -Os -static t.cpp -o t
g++ -Os -c fix.cpp -o fix.o && nm -C fix.o | grep 'basic_string(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&)'
nm /ucrt64/lib/libstdc++.dll.a | grep -c 'C1EOS4_' ; nm /ucrt64/lib/libstdc++.dll.a | grep 'NSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC[12]EOS4_' | head
nm -C /ucrt64/lib/libstdc++.a | grep 'basic_string(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&)' | head
g++ -Os -c t.cpp -o t.o && nm t.o | grep 'EOS4_'
