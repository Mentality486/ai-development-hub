import axios, { type AxiosInstance, type AxiosRequestConfig } from 'axios'

const instance: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 15000
})

instance.interceptors.request.use((config) => {
  const token = localStorage.getItem('aihub_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

instance.interceptors.response.use(
  (res) => {
    const body = res.data as { code?: number; message?: string; data?: unknown }
    if (body && typeof body === 'object' && 'code' in body) {
      if (body.code === 0) return body.data
      return Promise.reject(new Error(body.message || '请求失败'))
    }
    return res.data
  },
  (err) => {
    const status = err.response?.status
    if (status === 401) {
      localStorage.removeItem('aihub_token')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

/** 类型安全的 GET：返回的是 R.data 而非 AxiosResponse。 */
function get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
  return instance.get(url, config) as unknown as Promise<T>
}

/** 类型安全的 POST：返回的是 R.data 而非 AxiosResponse。 */
function post<T>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
  return instance.post(url, data, config) as unknown as Promise<T>
}

const http = { get, post, instance }
export default http
