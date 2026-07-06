cmake_minimum_required(VERSION 3.20)

# --- Target GPU architecture (set BEFORE project() so CUDA detection uses it) ---
# RTX 40-series (Ada) = 89 ,  50-series (Blackwell) = 120 ,  3090 (Ampere) = 86.
# Override on the command line:  -DCMAKE_CUDA_ARCHITECTURES=XX
if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
  set(CMAKE_CUDA_ARCHITECTURES 89)   # this machine: RTX 4070 Ti SUPER (Ada)
endif()

project(brain_phase0 LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Static runtimes -> self-contained exe (no cudart64_*.dll / VS redist hunt at runtime).
set(CMAKE_CUDA_RUNTIME_LIBRARY Static)
if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

find_package(CUDAToolkit REQUIRED)

add_executable(brain_phase0
  src/main.cu
  src/sim.cu
  src/connectome.cu
)
target_include_directories(brain_phase0 PRIVATE include)

# CUDA runtime + device curand (curand_kernel.h) for the per-neuron Poisson noise floor.
# Robust imported targets from CUDAToolkit -- not a fragile find_library() hint.
target_link_libraries(brain_phase0 PRIVATE CUDA::cudart_static CUDA::curand)

# Windows: kill the min/max macros (main.cu uses std::max) + CRT fopen warnings.
if(MSVC)
  target_compile_definitions(brain_phase0 PRIVATE NOMINMAX _CRT_SECURE_NO_WARNINGS)
endif()

# Optional: OpenMP makes host connectome generation multi-threaded (nice-to-have).
find_package(OpenMP QUIET)
if(OpenMP_CXX_FOUND)
  target_link_libraries(brain_phase0 PRIVATE OpenMP::OpenMP_CXX)
  target_compile_options(brain_phase0 PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=${OpenMP_CXX_FLAGS}>)
endif()

target_compile_options(brain_phase0 PRIVATE
  $<$<COMPILE_LANGUAGE:CUDA>:--use_fast_math>)

# --------------------------------------------------------------------------
# Build (Windows PowerShell, from the project root):
#   cmake -B build -S . -DCMAKE_CUDA_ARCHITECTURES=89
#   cmake --build build --config Release
#   ./build/Release/brain_phase0.exe        (optional: pass a seed, e.g. 7)
# --------------------------------------------------------------------------
