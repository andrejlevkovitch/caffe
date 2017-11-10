#include <cmath>
#include <cstdlib>
#include <cstring>
#include <functional>

#include "caffe/backend/cuda/cuda_device.hpp"
#include "caffe/util/math_functions.hpp"

#include "caffe/common.hpp"
#include "caffe/backend/backend.hpp"
#include "caffe/backend/vptr.hpp"
#include "caffe/backend/dev_ptr.hpp"
#include "caffe/backend/cuda/caffe_cuda.hpp"
#include "caffe/backend/cuda/cuda_dev_ptr.hpp"

#ifdef USE_CUDA
#include <math_functions.h>  // CUDA's, not caffe's, for fabs, signbit
#include <thrust/device_vector.h>
#include <thrust/functional.h>  // thrust::plus
#include <thrust/reduce.h>
#endif  // USE_CUDA

namespace caffe {

#ifdef USE_CUDA

void CudaDevice::memcpy(const uint_tp n, vptr<const void> x, vptr<void> y) {
  if (x.get_cuda_ptr() != y.get_cuda_ptr()) {
    CUDA_CHECK(cudaMemcpy(y.get_cuda_ptr(), x.get_cuda_ptr(),
                          n, cudaMemcpyDefault));  // NOLINT(caffe/alt_fn)
  }
}

void CudaDevice::memcpy(const uint_tp n, const void* x, vptr<void> y) {
  if (x != y.get_cuda_ptr()) {
    CUDA_CHECK(cudaMemcpy(y.get_cuda_ptr(), x,
                          n, cudaMemcpyDefault));  // NOLINT(caffe/alt_fn)
  }
}

void CudaDevice::memcpy(const uint_tp n, vptr<const void> x, void* y) {
  if (x.get_cuda_ptr() != y) {
    CUDA_CHECK(cudaMemcpy(y, x.get_cuda_ptr(),
                          n, cudaMemcpyDefault));  // NOLINT(caffe/alt_fn)
  }
}

void CudaDevice::rng_uniform(const uint_tp n, vptr<uint32_t> r) {
  CURAND_CHECK(curandGenerate(Caffe::curand_generator(), r.get_cuda_ptr(), n));
}

void CudaDevice::rng_uniform(const uint_tp n, vptr<uint64_t> r) {
  CURAND_CHECK(curandGenerateLongLong(Caffe::curand_generator64(),
                   reinterpret_cast<unsigned long long*>(r.get_cuda_ptr()), n));
}

void CudaDevice::rng_uniform_half(const uint_tp n, const half_fp a,
                                   const half_fp b,
                                   vptr<half_fp> r) {
  // TODO: CUDA based implementation
  vector<half_fp> random(n);  // NOLINT
  caffe_rng_uniform(n, a, b, &random[0]);
  this->memcpy(sizeof(half_fp) * n, &random[0], r);
}

void CudaDevice::rng_uniform_float(const uint_tp n, const float a,
                                    float b,
                                    vptr<float> r) {
  CURAND_CHECK(curandGenerateUniform(Caffe::curand_generator(),
                                     r.get_cuda_ptr(), n));
  const float range = b - a;
  if (range != static_cast<float>(1)) {
    CudaDevice::scal(n, range, r);
  }
  if (a != static_cast<float>(0)) {
    CudaDevice::add_scalar(n, a, r);
  }
}

void CudaDevice::rng_uniform_double(const uint_tp n, const double a,
                                    const double b,
                                    vptr<double> r) {
  CURAND_CHECK(curandGenerateUniformDouble(Caffe::curand_generator(),
                                           r.get_cuda_ptr(), n));
  const double range = b - a;
  if (range != static_cast<double>(1)) {
    CudaDevice::scal(n, range, r);
  }
  if (a != static_cast<double>(0)) {
    CudaDevice::add_scalar(n, a, r);
  }
}

void CudaDevice::rng_gaussian_half(const uint_tp n, const half_fp mu,
                                    const half_fp sigma,
                                    vptr<half_fp> r) {
  // TODO: CUDA based implementation
  vector<half_fp> random(n);  // NOLINT
  caffe_rng_gaussian(n, mu, sigma, &random[0]);
  this->memcpy(sizeof(half_fp) * n, &random[0], r);
}

void CudaDevice::rng_gaussian_float(const uint_tp n, const float mu,
                                     const float sigma, vptr<float> r) {
  CURAND_CHECK(
      curandGenerateNormal(Caffe::curand_generator(), r.get_cuda_ptr(),
                           n, mu, sigma));
}

void CudaDevice::rng_gaussian_double(const uint_tp n, const double mu,
                                      const double sigma, vptr<double> r) {
  CURAND_CHECK(
      curandGenerateNormalDouble(Caffe::curand_generator(), r.get_cuda_ptr(),
                                 n, mu, sigma));
}

void CudaDevice::rng_bernoulli_half(const uint_tp n, const half_fp p,
                                    vptr<int> r) {
  vector<half_fp> random(n);  // NOLINT
  caffe_rng_bernoulli(n, p, &random[0]);
  this->memcpy(sizeof(half_fp) * n, &random[0], r);
}

void CudaDevice::rng_bernoulli_float(const uint_tp n, const float p,
                                     vptr<int> r) {
  vector<float> random(n);  // NOLINT
  caffe_rng_bernoulli(n, p, &random[0]);
  this->memcpy(sizeof(float) * n, &random[0], r);
}

void CudaDevice::rng_bernoulli_double(const uint_tp n, const double p,
                                      vptr<int> r) {
  vector<double> random(n);  // NOLINT
  caffe_rng_bernoulli(n, p, &random[0]);
  this->memcpy(sizeof(double) * n, &random[0], r);
}

void CudaDevice::rng_bernoulli_half(const uint_tp n, const half_fp p,
                                    vptr<unsigned int> r) {
  vector<half_fp> random(n);  // NOLINT
  caffe_rng_bernoulli(n, p, &random[0]);
  this->memcpy(sizeof(half_fp) * n, &random[0], r);
}

void CudaDevice::rng_bernoulli_float(const uint_tp n, const float p,
                                     vptr<unsigned int> r) {
  vector<float> random(n);  // NOLINT
  caffe_rng_bernoulli(n, p, &random[0]);
  this->memcpy(sizeof(float) * n, &random[0], r);
}

void CudaDevice::rng_bernoulli_double(const uint_tp n, const double p,
                                      vptr<unsigned int> r) {
  vector<double> random(n);  // NOLINT
  caffe_rng_bernoulli(n, p, &random[0]);
  this->memcpy(sizeof(double) * n, &random[0], r);
}


#endif  // USE_CUDA

}  // namespace caffe
