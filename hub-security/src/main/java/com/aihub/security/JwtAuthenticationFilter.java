package com.aihub.security;

import com.aihub.common.ErrorCode;
import com.aihub.common.R;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/** 从 Authorization: Bearer <token> 解析 JWT 并设置安全上下文。 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String HEADER = "Authorization";
    private static final String PREFIX = "Bearer ";

    private final JwtService jwtService;
    private final ObjectMapper objectMapper;

    public JwtAuthenticationFilter(JwtService jwtService, ObjectMapper objectMapper) {
        this.jwtService = jwtService;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String auth = request.getHeader(HEADER);
        if (auth == null || !auth.startsWith(PREFIX)) {
            filterChain.doFilter(request, response);
            return;
        }
        try {
            Claims claims = jwtService.parseToken(auth.substring(PREFIX.length()));
            String username = claims.get("username", String.class);
            String userId = claims.getSubject();
            var principal = new LoginUser(Long.valueOf(userId), username);
            var authentication = new UsernamePasswordAuthenticationToken(
                    principal, null,
                    List.of(new SimpleGrantedAuthority("ROLE_USER")));
            SecurityContextHolder.getContext().setAuthentication(authentication);
            filterChain.doFilter(request, response);
        } catch (JwtException | IllegalArgumentException e) {
            SecurityContextHolder.clearContext();
            response.setStatus(HttpServletResponse.SC_OK);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setCharacterEncoding("UTF-8");
            objectMapper.writeValue(response.getWriter(), R.fail(ErrorCode.UNAUTHORIZED));
        }
    }

    /** 安全上下文中的登录用户。 */
    public record LoginUser(Long id, String username) {
    }
}
