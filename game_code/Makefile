# 回合制对战 - MinGW 构建脚本
# 用法: mingw32-make all
# 输出: build/battle.exe
# 注意: DLL 复制由 build 脚本/手动完成，见 run.bat

CXX      := g++
SFML     := third_party/SFML-2.5.1
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -Iinclude -I"$(SFML)/include"
LDFLAGS  := -static-libgcc -static-libstdc++ -L"$(SFML)/lib" -lsfml-graphics -lsfml-window -lsfml-system -lfreetype -lgdi32 -lws2_32 -lwinmm

SRCS := $(wildcard src/core/*.cpp) \
        src/config/ConfigParser.cpp \
        src/ai/AIController.cpp \
        src/ui/UIManager.cpp \
        src/main.cpp

OBJS := $(SRCS:.cpp=.o)
TARGET := build/battle.exe
LOGIC_TEST := build/test_logic.exe
RENDER_TEST := build/render_check.exe

all: $(TARGET)
	@echo Build OK: $(TARGET)

$(TARGET): $(OBJS)
	@if not exist build mkdir build
	$(CXX) $(OBJS) -o $@ $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

run: all
	./build/battle.exe

$(LOGIC_TEST): tests/test_logic.cpp src/core/BattleSystem.cpp src/config/ConfigParser.cpp src/ai/AIController.cpp
	@if not exist build mkdir build
	$(CXX) $(CXXFLAGS) $^ -o $@ -static-libgcc -static-libstdc++

$(RENDER_TEST): tests/render_check.cpp
	@if not exist build mkdir build
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDFLAGS)

test: $(LOGIC_TEST) $(RENDER_TEST)
	./$(LOGIC_TEST)
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test_coin_toss.ps1 -Executable ./$(LOGIC_TEST)
	./$(RENDER_TEST)

clean:
	-del /s /q src\core\*.o src\config\*.o src\ai\*.o src\ui\*.o src\*.o 2>nul
	-del /s /q build\battle.exe 2>nul
	@echo Cleaned.

.PHONY: all run test clean
