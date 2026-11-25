package com.aihub.web.auth;

import com.aihub.common.BusinessException;
import com.aihub.common.ErrorCode;
import com.aihub.common.R;
import com.aihub.security.JwtService;
import com.aihub.system.entity.SysUser;
import com.aihub.system.mapper.SysUserMapper;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

/** 登录接口。第一阶段只做账号密码登录，微信/渠道登录在第六阶段接入。 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final SysUserMapper userMapper;
    private final JwtService jwtService;
    private final BCryptPasswordEncoder passwordEncoder;

    public AuthController(SysUserMapper userMapper, JwtService jwtService) {
        this.userMapper = userMapper;
        this.jwtService = jwtService;
        this.passwordEncoder = new BCryptPasswordEncoder();
    }

    @PostMapping("/login")
    public R<Map<String, Object>> login(@Valid @RequestBody LoginRequest req) {
        SysUser user = userMapper.selectActiveByUsername(req.getUsername());
        if (user == null) {
            throw new BusinessException(ErrorCode.BAD_CREDENTIALS);
        }
        if (!passwordEncoder.matches(req.getPassword(), user.getPasswordHash())) {
            throw new BusinessException(ErrorCode.BAD_CREDENTIALS);
        }
        if ("DISABLED".equals(user.getStatus())) {
            throw new BusinessException(ErrorCode.USER_DISABLED);
        }
        user.setLastLoginAt(LocalDateTime.now());
        userMapper.updateById(user);

        String token = jwtService.generateToken(user.getId(), user.getUsername());
        return R.ok(Map.of(
                "token", token,
                "tokenType", "Bearer",
                "expiresIn", 8 * 60 * 60,
                "user", Map.of(
                        "id", user.getId(),
                        "username", user.getUsername(),
                        "displayName", user.getDisplayName() == null ? user.getUsername() : user.getDisplayName())));
    }

    @Data
    public static class LoginRequest {
        @NotBlank(message = "用户名不能为空")
        private String username;
        @NotBlank(message = "密码不能为空")
        private String password;
    }
}
