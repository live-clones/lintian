cmake_minimum_required(VERSION 3.13)
project(hello)

add_executable(hello hello.c)

install(TARGETS hello)
