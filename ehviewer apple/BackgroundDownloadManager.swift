//
//  BackgroundDownloadManager.swift
//  ehviewer apple
//
//  后台下载管理器 — 使用 URLSession background configuration
//

import Foundation
import BackgroundTasks

/// 后台下载管理器
/// 负责在 App 进入后台或被挂起时继续下载
final class BackgroundDownloadManager: NSObject, @unchecked Sendable {
    static let shared = BackgroundDownloadManager()

    private let downloadTaskIdentifier = "Stellatrix.ehviewer-apple.download"
    private let refreshTaskIdentifier = "Stellatrix.ehviewer-apple.refresh"

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.stellatrix.ehviewer.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// 存储下载完成回调
    var backgroundCompletionHandler: (() -> Void)?

    /// 存储当前下载任务
    private var activeTasks: [Int: DownloadTaskInfo] = [:]

    /// 防止重复注册后台任务
    private var isRegistered = false

    private override init() {
        super.init()
    }

    // MARK: - Background Task Registration

    /// 注册后台任务 (在 App 启动时调用, 仅注册一次)
    func registerBackgroundTasks() {
        guard !isRegistered else { return }
        isRegistered = true
        #if os(iOS) && !targetEnvironment(simulator)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: downloadTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundDownload(task: task as! BGProcessingTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        #endif
    }

    /// 调度后台下载任务
    func scheduleBackgroundDownload() {
        #if os(iOS) && !targetEnvironment(simulator)
        let request = BGProcessingTaskRequest(identifier: downloadTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background download task scheduled")
        } catch {
            print("Failed to schedule background download: \(error)")
        }
        #endif
    }

    /// 调度后台刷新任务
    func scheduleBackgroundRefresh() {
        #if os(iOS) && !targetEnvironment(simulator)
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分钟后

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
        #endif
    }

    // MARK: - Task Handlers

    #if os(iOS) && !targetEnvironment(simulator)
    private func handleBackgroundDownload(task: BGProcessingTask) {
        scheduleBackgroundDownload() // 重新调度

        task.expirationHandler = {
            // 任务过期时暂停下载
            self.pauseAllDownloads()
        }

        // 继续下载队列
        Task {
            // 这里会调用 DownloadManager 继续下载
            task.setTaskCompleted(success: true)
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh() // 重新调度

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // 检查下载状态
        Task {
            task.setTaskCompleted(success: true)
        }
    }
    #endif

    private func pauseAllDownloads() {
        backgroundSession.getAllTasks { tasks in
            tasks.forEach { $0.suspend() }
        }
    }

    // MARK: - Download Methods

    /// 开始下载图片 (后台兼容)
    func downloadImage(url: URL, to destination: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = backgroundSession.downloadTask(with: url)
        let taskInfo = DownloadTaskInfo(destinationURL: destination, completion: completion)
        activeTasks[task.taskIdentifier] = taskInfo
        task.resume()
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskInfo = activeTasks[downloadTask.taskIdentifier] else { return }

        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: taskInfo.destinationURL.path) {
                try FileManager.default.removeItem(at: taskInfo.destinationURL)
            }

            // 确保目录存在
            let dir = taskInfo.destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // 移动文件
            try FileManager.default.moveItem(at: location, to: taskInfo.destinationURL)
            taskInfo.completion(.success(taskInfo.destinationURL))
        } catch {
            taskInfo.completion(.failure(error))
        }

        activeTasks.removeValue(forKey: downloadTask.taskIdentifier)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let taskInfo = activeTasks[task.taskIdentifier] else { return }

        taskInfo.completion(.failure(error))
        activeTasks.removeValue(forKey: task.taskIdentifier)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // 后台下载完成，通知系统
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Download Task Info

private struct DownloadTaskInfo {
    let destinationURL: URL
    let completion: (Result<URL, Error>) -> Void
}
