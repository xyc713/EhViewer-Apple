//
//  DownloadNotificationBridge.swift
//  ehviewer apple
//
//  桥接 DownloadManager 和 DownloadNotificationService
//  负责在下载事件发生时转发到通知服务
//

import Foundation
import EhDownload

/// 桥接 DownloadManager 的监听器到 DownloadNotificationService
final class DownloadNotificationBridge: DownloadListener, @unchecked Sendable {
    static let shared = DownloadNotificationBridge()

    private init() {}

    // MARK: - DownloadListener

    func onDownloadStart(gid: Int64, title: String) async {
        await MainActor.run {
            DownloadNotificationService.shared.onDownloadStart(gid: gid, title: title)
        }
    }

    func onDownloadProgress(gid: Int64, title: String, downloaded: Int, total: Int, speed: Int64) async {
        await MainActor.run {
            DownloadNotificationService.shared.onDownloadProgress(
                gid: gid,
                title: title,
                downloaded: downloaded,
                total: total,
                speed: speed
            )
        }
    }

    func onDownloadFinish(gid: Int64, title: String, success: Bool) async {
        await MainActor.run {
            DownloadNotificationService.shared.onDownloadFinish(gid: gid, title: title, success: success)
        }
    }

    func on509Error() async {
        await MainActor.run {
            DownloadNotificationService.shared.on509Error()
        }
    }
}
