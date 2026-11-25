package com.aihub.common;

/**
 * 统一错误码。
 * 段位规则：1xxxx 通用 / 2xxxx 认证授权 / 3xxxx Agent / 4xxxx 任务 / 5xxxx 项目 / 6xxxx 微信渠道。
 */
public enum ErrorCode {

    SUCCESS(0, "ok"),
    PARAM_INVALID(10001, "参数校验失败"),
    INTERNAL_ERROR(10002, "系统内部错误"),
    NOT_FOUND(10003, "资源不存在"),

    UNAUTHORIZED(20001, "未登录或登录已失效"),
    FORBIDDEN(20002, "无权限执行此操作"),
    BAD_CREDENTIALS(20003, "用户名或密码错误"),
    USER_DISABLED(20004, "用户已禁用"),
    WECHAT_NOT_IN_WHITELIST(20005, "微信用户不在白名单中"),

    AGENT_NOT_FOUND(30001, "Agent 不存在"),
    AGENT_OFFLINE(30002, "Agent 离线"),
    AGENT_BUSY(30003, "Agent 忙碌"),

    TASK_NOT_FOUND(40001, "任务不存在"),
    TASK_STATE_INVALID(40002, "任务状态不允许此操作"),

    PROJECT_NOT_FOUND(50001, "项目不存在"),
    PROJECT_PATH_INVALID(50002, "项目路径必须为 WSL Linux 路径");

    private final int code;
    private final String message;

    ErrorCode(int code, String message) {
        this.code = code;
        this.message = message;
    }

    public int getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }
}
