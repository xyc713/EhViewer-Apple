//
//  SecurityView.swift
//  ehviewer apple
//
//  安全锁屏视图 (对应 Android SecurityScene)
//  支持 Face ID / Touch ID 生物识别解锁
//

import SwiftUI
import LocalAuthentication

/// 安全锁屏视图
/// 应用启动时如果启用了安全功能，需要先通过认证
struct SecurityView: View {
    let onAuthenticated: () -> Void
    
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var retryCount = 0
    
    private let maxRetries = 5
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 锁图标
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            
            Text("EhViewer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("请验证身份以继续")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // 生物识别图标
            biometricIcon
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.top, 24)
            
            if let error = authError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // 解锁按钮
            Button(action: authenticate) {
                HStack {
                    Image(systemName: biometricSystemImage)
                    Text("使用 \(biometricName) 解锁")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating || retryCount >= maxRetries)
            .padding(.horizontal, 32)
            
            if retryCount >= maxRetries {
                Text("重试次数过多，请稍后再试")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            
            // 重试计数
            if retryCount > 0 && retryCount < maxRetries {
                Text("剩余尝试次数: \(maxRetries - retryCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // 自动触发认证
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticate()
            }
        }
    }
    
    // MARK: - 生物识别类型
    
    private var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    private var biometricName: String {
        switch biometricType {
        case .none:
            return "密码"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "生物识别"
        }
    }
    
    private var biometricSystemImage: String {
        switch biometricType {
        case .none:
            return "lock.shield"
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        @unknown default:
            return "lock.shield"
        }
    }
    
    @ViewBuilder
    private var biometricIcon: some View {
        switch biometricType {
        case .none:
            Image(systemName: "lock.shield")
        case .faceID:
            Image(systemName: "faceid")
        case .touchID:
            Image(systemName: "touchid")
        case .opticID:
            Image(systemName: "opticid")
        @unknown default:
            Image(systemName: "lock.shield")
        }
    }
    
    // MARK: - 认证
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        guard retryCount < maxRetries else { return }
        
        isAuthenticating = true
        authError = nil
        
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        
        var error: NSError?
        
        // 检查是否支持生物识别
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // 使用生物识别
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "验证身份以访问 EhViewer"
            ) { success, authenticationError in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        onAuthenticated()
                    } else {
                        handleAuthError(authenticationError)
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // 回退到设备密码
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "验证身份以访问 EhViewer"
            ) { success, authenticationError in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        onAuthenticated()
                    } else {
                        handleAuthError(authenticationError)
                    }
                }
            }
        } else {
            // 设备不支持任何认证方式
            isAuthenticating = false
            authError = "此设备不支持生物识别或密码认证"
        }
    }
    
    private func handleAuthError(_ error: Error?) {
        retryCount += 1
        
        guard let laError = error as? LAError else {
            authError = error?.localizedDescription
            return
        }
        
        switch laError.code {
        case .userCancel:
            authError = "认证已取消"
        case .userFallback:
            // 用户选择使用密码
            authError = nil
        case .biometryNotAvailable:
            authError = "生物识别不可用"
        case .biometryNotEnrolled:
            authError = "未设置生物识别"
        case .biometryLockout:
            authError = "生物识别已锁定，请使用密码"
        case .authenticationFailed:
            authError = "认证失败"
        default:
            authError = laError.localizedDescription
        }
    }
}

#Preview {
    SecurityView(onAuthenticated: { print("Authenticated") })
}
