package com.aihub.security;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "hub.security.jwt")
public class JwtProperties {

    /** HMAC 密钥，建议 32+ 字节；生产通过环境变量覆盖。 */
    private String secret = "ai-hub-dev-secret-change-me-in-production-please-32bytes";

    /** 令牌有效期（毫秒），默认 8 小时。 */
    private long expirationMs = 8 * 60 * 60 * 1000L;

    private String issuer = "ai-development-hub";

    public String getSecret() {
        return secret;
    }

    public void setSecret(String secret) {
        this.secret = secret;
    }

    public long getExpirationMs() {
        return expirationMs;
    }

    public void setExpirationMs(long expirationMs) {
        this.expirationMs = expirationMs;
    }

    public String getIssuer() {
        return issuer;
    }

    public void setIssuer(String issuer) {
        this.issuer = issuer;
    }
}
