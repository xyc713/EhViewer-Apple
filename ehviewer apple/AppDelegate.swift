//
//  AppDelegate.swift
//  ehviewer apple
//
//  iOS App Delegate — 处理后台下载回调
//

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    /// 后台下载完成回调
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // 存储完成回调，在 URLSession delegate 中调用
        BackgroundDownloadManager.shared.backgroundCompletionHandler = completionHandler
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 注册后台任务
        BackgroundDownloadManager.shared.registerBackgroundTasks()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // 调度后台下载任务
        BackgroundDownloadManager.shared.scheduleBackgroundDownload()
    }
}
#endif
