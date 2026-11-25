<template>
  <el-container class="layout">
    <el-aside width="220px">
      <div class="logo">🤖 AI 研发中枢</div>
      <el-menu :default-active="route.path" router background-color="#1d2129" text-color="#c9cdd4" active-text-color="#409eff">
        <el-menu-item index="/dashboard"><el-icon><DataBoard /></el-icon>系统首页</el-menu-item>
        <el-menu-item disabled><el-icon><Cpu /></el-icon>Agent 管理</el-menu-item>
        <el-menu-item disabled><el-icon><Tickets /></el-icon>任务管理</el-menu-item>
        <el-menu-item disabled><el-icon><Folder /></el-icon>项目管理</el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header>
        <span>{{ (route.meta.title as string) || 'AI 研发中枢' }}</span>
        <div class="header-right">
          <span>{{ auth.username }}</span>
          <el-button text @click="logout">退出</el-button>
        </div>
      </el-header>
      <el-main><router-view /></el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import { DataBoard, Cpu, Tickets, Folder } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

function logout() {
  auth.logout()
  router.push('/login')
}
</script>

<style scoped>
.layout { height: 100%; }
.el-aside { background: #1d2129; }
.logo { height: 60px; line-height: 60px; text-align: center; color: #fff; font-weight: bold; font-size: 16px; border-bottom: 1px solid #30353d; }
.el-header { background: #fff; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #e5e6eb; }
.header-right { display: flex; align-items: center; gap: 12px; }
.el-main { background: #f5f7fa; padding: 20px; }
</style>
