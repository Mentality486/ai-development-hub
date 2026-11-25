package com.aihub.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

/** JWT 签发与校验。密钥从 JwtProperties 读取，禁止输出 token 到日志。 */
@Service
public class JwtService {

    private final JwtProperties props;

    public JwtService(JwtProperties props) {
        this.props = props;
    }

    public String generateToken(Long userId, String username) {
        Instant now = Instant.now();
        return Jwts.builder()
                .issuer(props.getIssuer())
                .subject(String.valueOf(userId))
                .claim("username", username)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusMillis(props.getExpirationMs())))
                .signWith(getKey())
                .compact();
    }

    public Claims parseToken(String token) {
        return Jwts.parser()
                .verifyWith(getKey())
                .requireIssuer(props.getIssuer())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private SecretKey getKey() {
        return Keys.hmacShaKeyFor(props.getSecret().getBytes(StandardCharsets.UTF_8));
    }
}
