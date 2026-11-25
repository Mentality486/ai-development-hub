import { defineStore } from 'pinia'
import { ref } from 'vue'
import http from '@/api'

interface LoginResult {
  token: string
  tokenType: string
  expiresIn: number
  user: { id: number; username: string; displayName: string }
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('aihub_token') || '')
  const username = ref(localStorage.getItem('aihub_user') || '')

  async function login(user: string, password: string) {
    const data = await http.post<LoginResult>('/auth/login', { username: user, password })
    token.value = data.token
    username.value = data.user.displayName
    localStorage.setItem('aihub_token', data.token)
    localStorage.setItem('aihub_user', data.user.displayName)
  }

  function logout() {
    token.value = ''
    username.value = ''
    localStorage.removeItem('aihub_token')
    localStorage.removeItem('aihub_user')
  }

  return { token, username, login, logout }
})
