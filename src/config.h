// change these defines via cmake, not by editing this file
// we just define the defaults here

// build libmoon as static library without main()
//#define LIBMOON_BUILD_LIB

// the lua module loaded on startup of a new task
#ifndef LIBMOON_LUA_MAIN_MODULE
#define LIBMOON_LUA_MAIN_MODULE "main"
#endif
