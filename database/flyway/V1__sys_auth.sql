-- V1: 系统用户 / 角色 / 权限及关联表，含内置管理员
-- 所有 CREATE 均 IF NOT EXISTS，保证脚本可重复初始化（空库到最新）

CREATE TABLE IF NOT EXISTS sys_user (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL COMMENT '登录名',
  password_hash VARCHAR(100) NOT NULL COMMENT 'BCrypt',
  display_name VARCHAR(64) DEFAULT NULL,
  wechat_id VARCHAR(128) DEFAULT NULL COMMENT '微信发送者标识（白名单依据）',
  phone VARCHAR(32) DEFAULT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE/DISABLED',
  last_login_at DATETIME(3) DEFAULT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_sys_user_username (username),
  UNIQUE KEY uk_sys_user_wechat_id (wechat_id),
  KEY idx_sys_user_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统用户';

CREATE TABLE IF NOT EXISTS sys_role (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL COMMENT 'ADMIN/OPERATOR/VIEWER',
  name VARCHAR(64) NOT NULL,
  description VARCHAR(255) DEFAULT NULL,
  builtin TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_sys_role_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='角色';

CREATE TABLE IF NOT EXISTS sys_permission (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(100) NOT NULL COMMENT '如 task:create / agent:discover',
  name VARCHAR(100) NOT NULL,
  type VARCHAR(32) NOT NULL COMMENT 'MENU/API/ACTION',
  parent_id BIGINT UNSIGNED DEFAULT NULL,
  sort INT NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_sys_permission_code (code),
  KEY idx_sys_permission_parent (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='权限';

CREATE TABLE IF NOT EXISTS sys_user_role (
  user_id BIGINT UNSIGNED NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),
  KEY idx_sys_user_role_role (role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户-角色关联';

CREATE TABLE IF NOT EXISTS sys_role_permission (
  role_id BIGINT UNSIGNED NOT NULL,
  permission_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  KEY idx_sys_role_permission_perm (permission_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色-权限关联';

-- 内置角色（幂等）
INSERT INTO sys_role (code, name, description, builtin) VALUES
  ('ADMIN', '系统管理员', '全部权限', 1),
  ('OPERATOR', '运维人员', '日常操作与审批', 1),
  ('VIEWER', '只读用户', '查看仪表盘与任务', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- 内置管理员：admin / Admin@123456（BCrypt, $2b$10$）
-- 密码仅用于首次启动，登录后应立即修改
INSERT INTO sys_user (username, password_hash, display_name, status) VALUES
  ('admin', '$2b$10$sa4TkYIy0VsjOMD25ZTU2OwFVm7GyX8MqsUbpVjAJiGeyfkUeqQDu', '系统管理员', 'ACTIVE')
ON DUPLICATE KEY UPDATE username = username;

INSERT INTO sys_user_role (user_id, role_id)
SELECT u.id, r.id FROM sys_user u, sys_role r
WHERE u.username = 'admin' AND r.code = 'ADMIN'
ON DUPLICATE KEY UPDATE user_id = user_id;
