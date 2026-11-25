<template>
  <div>
    <el-row :gutter="16">
      <el-col :span="6"><el-card><div class="stat"><div class="label">Agent 总数</div><div class="value">—</div></div></el-card></el-col>
      <el-col :span="6"><el-card><div class="stat"><div class="label">今日任务</div><div class="value">—</div></div></el-card></el-col>
      <el-col :span="6"><el-card><div class="stat"><div class="label">执行中</div><div class="value">—</div></div></el-card></el-col>
      <el-col :span="6"><el-card><div class="stat"><div class="label">微信连接</div><div class="value">—</div></div></el-card></el-col>
    </el-row>
    <el-card style="margin-top:16px">
      <template #header>系统状态</template>
      <el-alert type="info" :closable="false" title="第一阶段基础工程已就绪：后端登录、数据库迁移、前端框架均可用。统计指标将在后续阶段接入真实接口。" />
    </el-card>
  </div>
</template>

<script setup lang="ts">
// 第一阶段占位：指标卡片在后续阶段接入真实 API，不使用静态假数据冒充功能。
</script>

<style scoped>
.stat .label { color: #86909c; font-size: 13px; }
.stat .value { font-size: 28px; font-weight: 600; margin-top: 8px; }
</style>
