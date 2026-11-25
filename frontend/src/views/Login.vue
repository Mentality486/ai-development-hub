<template>
  <div class="login-page">
    <el-card class="login-card">
      <h2>AI 研发中枢</h2>
      <p class="subtitle">AI Development Hub · 管理后台</p>
      <el-form :model="form" @keyup.enter="submit">
        <el-form-item>
          <el-input v-model="form.username" placeholder="用户名" :prefix-icon="User" size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" type="password" placeholder="密码" :prefix-icon="Lock" size="large" show-password />
        </el-form-item>
        <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon />
        <el-button type="primary" size="large" style="width:100%;margin-top:8px" :loading="loading" @click="submit">登录</el-button>
      </el-form>
      <p class="hint">默认账号 admin / Admin@123456（首次登录后请修改）</p>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { User, Lock } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'

const form = ref({ username: 'admin', password: '' })
const error = ref('')
const loading = ref(false)
const router = useRouter()
const auth = useAuthStore()

async function submit() {
  error.value = ''
  loading.value = true
  try {
    await auth.login(form.value.username, form.value.password)
    router.push('/dashboard')
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : '登录失败'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page { height: 100%; display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #1a2a6c 0%, #2a5298 100%); }
.login-card { width: 380px; padding: 20px; }
.login-card h2 { text-align: center; margin: 0 0 4px; }
.subtitle { text-align: center; color: #909399; margin: 0 0 24px; font-size: 13px; }
.hint { text-align: center; color: #a8abb2; font-size: 12px; margin: 16px 0 0; }
</style>
