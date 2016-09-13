// change these defines via cmake, not by editing this file
// we just define the defaults here

// build phobos as static library without main()
//#define PHOBOS_BUILD_LIB

// the lua module loaded on startup of a new task
#ifndef PHOBOS_LUA_MAIN_MODULE
#define PHOBOS_LUA_MAIN_MODULE "main"
#endif
