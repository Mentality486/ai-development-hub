package com.aihub.web.system;

import com.aihub.common.R;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 健康检查接口。供部署脚本、反代和监控使用，无需登录。
 * 会真实探测数据库连通性，不是返回固定 true。
 */
@RestController
@RequestMapping("/api/health")
public class HealthController {

    private static final Logger log = LoggerFactory.getLogger(HealthController.class);

    private final JdbcTemplate jdbcTemplate;
    private final String appName;

    public HealthController(JdbcTemplate jdbcTemplate,
                            @Value("${spring.application.name:ai-development-hub}") String appName) {
        this.jdbcTemplate = jdbcTemplate;
        this.appName = appName;
    }

    @GetMapping
    public R<Map<String, Object>> health() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("app", appName);
        body.put("time", OffsetDateTime.now().toString());
        body.put("database", probeDatabase());
        // Redis 探活：RedisTemplate 由 spring-boot-starter-data-redis 提供，此处仅报数据库，
        // Redis 在 Agent/会话模块启用后纳入（避免当前阶段无 Redis 使用时误报 DOWN）
        String overall = "UP".equals(body.get("database")) ? "UP" : "DEGRADED";
        body.put("status", overall);
        return R.ok(body);
    }

    private String probeDatabase() {
        try {
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            return "UP";
        } catch (Exception e) {
            log.warn("数据库健康检查失败: {}", e.getMessage());
            return "DOWN";
        }
    }
}
