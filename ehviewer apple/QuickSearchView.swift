//
//  QuickSearchView.swift
//  ehviewer apple
//
//  快速搜索管理视图
//

import SwiftUI
import EhModels
import EhDatabase

struct QuickSearchView: View {
    @State private var vm = QuickSearchViewModel()
    @State private var showAddSheet = false
    @Binding var selectedSearch: QuickSearchRecord?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.searches.isEmpty {
                    ContentUnavailableView("暂无快速搜索",
                        systemImage: "magnifyingglass",
                        description: Text("点击右上角添加常用搜索词"))
                } else {
                    searchList
                }
            }
            .navigationTitle("快速搜索")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddQuickSearchSheet(vm: vm)
            }
        }
        .task {
            vm.loadSearches()
        }
    }

    private var searchList: some View {
        List {
            ForEach(vm.searches, id: \.id) { search in
                Button {
                    selectedSearch = search
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(search.name ?? search.keyword ?? "未命名")
                                .font(.body)
                                .foregroundStyle(.primary)

                            if let keyword = search.keyword, !keyword.isEmpty {
                                Text(keyword)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                vm.delete(at: indexSet)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}

// MARK: - Add Quick Search Sheet

struct AddQuickSearchSheet: View {
    @Bindable var vm: QuickSearchViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var keyword = ""
    @State private var minRating = 0
    @State private var selectedCategories: Set<EhCategory> = []

    private let allCategories: [EhCategory] = [
        .doujinshi, .manga, .artistCG, .gameCG, .western,
        .nonH, .imageSet, .cosplay, .asianPorn, .misc
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称 (可选)", text: $name)
                    TextField("搜索关键词", text: $keyword)
                }

                Section("最低评分") {
                    Picker("最低评分", selection: $minRating) {
                        Text("不限").tag(0)
                        ForEach(2...5, id: \.self) { rating in
                            HStack {
                                ForEach(0..<rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .tag(rating)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("分类筛选") {
                    ForEach(allCategories, id: \.rawValue) { category in
                        Toggle(category.name, isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { isOn in
                                if isOn {
                                    selectedCategories.insert(category)
                                } else {
                                    selectedCategories.remove(category)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("添加快速搜索")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(keyword.isEmpty)
                }
            }
        }
    }

    private func save() {
        let categoryMask = selectedCategories.reduce(0) { $0 | $1.rawValue }
        let record = QuickSearchRecord(
            name: name.isEmpty ? nil : name,
            mode: 0,
            category: categoryMask,
            keyword: keyword
        )
        vm.addSearch(record)
    }
}

// MARK: - ViewModel

@Observable
class QuickSearchViewModel {
    var searches: [QuickSearchRecord] = []

    func loadSearches() {
        do {
            searches = try EhDatabase.shared.getAllQuickSearches()
        } catch {
            print("Failed to load quick searches: \(error)")
        }
    }

    func addSearch(_ record: QuickSearchRecord) {
        do {
            try EhDatabase.shared.insertQuickSearch(record)
            loadSearches()
        } catch {
            print("Failed to add quick search: \(error)")
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            guard let id = searches[index].id else { continue }
            do {
                try EhDatabase.shared.deleteQuickSearch(id: id)
            } catch {
                print("Failed to delete quick search: \(error)")
            }
        }
        searches.remove(atOffsets: offsets)
    }
}

#Preview {
    QuickSearchView(selectedSearch: .constant(nil))
}
