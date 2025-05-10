cmake_minimum_required(VERSION 3.20.0)

project(ModelViewer VERSION 0.1.0 LANGUAGES CXX OBJCXX)

# C++17 표준 사용
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Objective-C++ 설정
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

# Metal 컴파일러 경로 설정
find_program(METAL_COMPILER xcrun)

# macOS 버전 설정 (최소 요구 버전: 10.14)
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.14" CACHE STRING "Minimum macOS version")

set(DEPS_DIR ${CMAKE_SOURCE_DIR}/deps)
set(DEPS_INCLUDE_DIR ${DEPS_DIR}/include)

# 소스 파일 목록
set(SOURCES
    src/main.mm
    src/GLTFLoader.mm
    src/Renderer.mm
    src/ViewController.mm
    src/MathBase.mm
    src/AppDelegate.mm
)

# 헤더 파일 목록
set(HEADERS
    src/GLTFLoader.h
    src/Renderer.h
    src/ViewController.h
    src/MathBase.h
    src/AppDelegate.h
)

# Metal 셰이더 파일 목록
set(METAL_SOURCES
    src/Shaders.metal
)

source_group("Shaders" FILES ${METAL_SOURCES})

# Metal 셰이더 컴파일 함수
function(compile_metal_shader source_file output_file)
    add_custom_command(
        OUTPUT ${output_file}
        COMMAND ${METAL_COMPILER} -sdk macosx metal -frecord-sources -gline-tables-only -c ${source_file} -o ${output_file}
        DEPENDS ${source_file}
        COMMENT "Compiling Metal shader ${source_file}"
    )
endfunction()

# 프로젝트 내의 각 Metal 셰이더 파일 컴파일
set(METAL_COMPILED_FILES)

foreach(metal_source ${METAL_SOURCES})
    get_filename_component(filename_without_ext ${metal_source} NAME_WE)
    set(output_file "${CMAKE_BINARY_DIR}/${filename_without_ext}.air")
    compile_metal_shader(${CMAKE_CURRENT_SOURCE_DIR}/${metal_source} ${output_file})
    list(APPEND METAL_COMPILED_FILES ${output_file})
endforeach()

# Metal 라이브러리 생성
set(METAL_LIBRARY "${CMAKE_BINARY_DIR}/default.metallib")
add_custom_command(
    OUTPUT ${METAL_LIBRARY}
    COMMAND ${METAL_COMPILER} -sdk macosx metallib ${METAL_COMPILED_FILES} -o ${METAL_LIBRARY}
    DEPENDS ${METAL_COMPILED_FILES}
    COMMENT "Creating Metal library"
)
add_custom_target(metal_library DEPENDS ${METAL_LIBRARY})

# 실행 파일 생성
add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SOURCES} ${HEADERS} ${METAL_SOURCES} ${METAL_LIBRARY})

# Metal 라이브러리 의존성 추가
add_dependencies(${PROJECT_NAME} metal_library)

# Metal 라이브러리를 번들에 포함시키기
set_target_properties(${PROJECT_NAME} PROPERTIES
    RESOURCE "${METAL_LIBRARY}"
    RESOURCE "${METAL_SOURCES}"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
)

# 필요한 프레임워크 링크
target_link_libraries(${PROJECT_NAME} PRIVATE
    "-framework AppKit"
    "-framework Metal"
    "-framework MetalKit"
    "-framework Foundation"
    "-framework QuartzCore"
)

# 헤더 파일 경로 추가
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${DEPS_INCLUDE_DIR}
)

# main.mm에서 NSApplication을 초기화하기 위한 플래그 설정
target_compile_definitions(${PROJECT_NAME} PRIVATE
    ModelViewer_BUNDLE_ID="com.example.ModelViewer"
)
