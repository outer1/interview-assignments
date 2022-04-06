//
//  AppInfoViewModel.swift
//  DemoApp
//
//  Created by xiongmin on 2022/4/2.
//

import Foundation
import Combine

struct AppInfoListResponse: Decodable {
    let resultCount: Int
    let results: [AppInfoModel]
}

// 需要在主线程进行UI操作，这里直接用MainActor修饰，不在函数内部处理
@MainActor class AppInfoViewModel: ObservableObject {
    @Published var appInfoList: [AppInfoModel] = []
    @Published var hasMore: Bool = true
    @Published var shouldShowErrorView = false
    
    var tipsMsg: String = "request failed please retry."
    
    // 首次加载标志
    private(set) var firstLoading = true
    
    let path = "https://itunes.apple.com/search"
    
    private var pageSize: Int = 10 // 每页数量
    private var limit: Int = 50 // 单次请求总数量
    private var response: AppInfoListResponse?
    
    func refresh(pageSize: Int = 10, limit: Int = 50) async {
        if firstLoading {
            firstLoading = false
        }
        guard pageSize > 0, limit > 0, pageSize <= limit else {
            let msg = "pageSize or limit should not less than or equal to 0"
            print("invalid parmas: \(msg)")
            self.tipsMsg = "error msg: invalid parameters."
            shouldShowErrorView = true
            return
        }
        self.pageSize = pageSize
        self.limit = limit
        let parmas: [String: AnyHashable] = ["entity": "software", "limit": limit, "term": "chat"]
        do {
            response = try await Network.shared.fetch(path, paramas: parmas)
            guard let response = self.response else { return }
            appInfoList.removeAll()
            if response.resultCount > pageSize {
                hasMore = true
                appInfoList.append(contentsOf: response.results.prefix(pageSize))
            } else {
                hasMore = false
                appInfoList.append(contentsOf: response.results)
            }
            shouldShowErrorView = false
            
        } catch {
            self.tipsMsg = "error msg: \(error.localizedDescription)"
            shouldShowErrorView = true
        }
    }
    
    func loadMore() async {
        guard let response = self.response else { return }
        let currentCount = appInfoList.count
        if currentCount < response.resultCount  {
            // 获取的数据数量还够，那么增加一页数量
            if currentCount + self.pageSize < response.resultCount {
                // 增加一页数量后如果还小于总数量，那么可以继续loadMore
                self.appInfoList.append(contentsOf: response.results[currentCount..<(currentCount + self.pageSize)])
                self.hasMore = true
            } else {
                self.appInfoList.append(contentsOf: response.results[currentCount..<response.resultCount])
                self.hasMore = false
            }
        } else {
            // 需要拿新的数据， 接口没有获取后续数据的机制，这里就直接置为没更多数据
            self.hasMore = false
        }
    }
}
