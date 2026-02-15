//
//  FilterView.swift
//  ehviewer apple
//
//  标签过滤管理视图
//

import SwiftUI
import EhDatabase

struct FilterView: View {
    @State private var vm = FilterViewModel()
    @State private var showAddSheet = false

    var body: some View {
        List {
            // 启用的过滤器
            Section {
                ForEach(vm.filters.filter { $0.enable }, id: \.id) { filter in
                    FilterRow(filter: filter) {
                        vm.toggleFilter(filter)
                    }
                }
                .onDelete { indexSet in
                    vm.deleteEnabled(at: indexSet)
                }
            } header: {
                Text("已启用")
            } footer: {
                if vm.filters.filter({ $0.enable }).isEmpty {
                    Text("没有启用的过滤器")
                }
            }

            // 禁用的过滤器
            let disabledFilters = vm.filters.filter { !$0.enable }
            if !disabledFilters.isEmpty {
                Section("已禁用") {
                    ForEach(disabledFilters, id: \.id) { filter in
                        FilterRow(filter: filter) {
                            vm.toggleFilter(filter)
                        }
                    }
                    .onDelete { indexSet in
                        vm.deleteDisabled(at: indexSet)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("标签过滤")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddFilterSheet(vm: vm)
        }
        .task {
            vm.loadFilters()
        }
    }
}

// MARK: - Filter Row

struct FilterRow: View {
    let filter: FilterRecord
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(filter.text ?? "")
                    .font(.body)

                Text(filterModeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: .constant(filter.enable))
                .labelsHidden()
                .onChange(of: filter.enable) { _, _ in
                    onToggle()
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }

    private var filterModeText: String {
        switch filter.mode {
        case 0: return "标题过滤"
        case 1: return "上传者过滤"
        case 2: return "标签过滤"
        case 3: return "标签命名空间过滤"
        case 4: return "上传者标签过滤"
        case 5: return "语言过滤"
        default: return "未知类型"
        }
    }
}

// MARK: - Add Filter Sheet

struct AddFilterSheet: View {
    @Bindable var vm: FilterViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var filterText = ""
    @State private var filterMode = 2  // 默认标签过滤

    private let filterModes: [(Int, String)] = [
        (0, "标题"),
        (1, "上传者"),
        (2, "标签"),
        (3, "标签命名空间"),
        (4, "上传者标签"),
        (5, "语言")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("过滤内容") {
                    TextField("输入要过滤的文本", text: $filterText)

                    Picker("过滤类型", selection: $filterMode) {
                        ForEach(filterModes, id: \.0) { mode, name in
                            Text(name).tag(mode)
                        }
                    }
                }

                Section {
                    Text(filterDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加过滤器")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        vm.addFilter(text: filterText, mode: filterMode)
                        dismiss()
                    }
                    .disabled(filterText.isEmpty)
                }
            }
        }
    }

    private var filterDescription: String {
        switch filterMode {
        case 0: return "含有此文本的标题将被过滤"
        case 1: return "此上传者的画廊将被过滤"
        case 2: return "含有此标签的画廊将被过滤 (格式: namespace:tag)"
        case 3: return "含有此命名空间下任何标签的画廊将被过滤"
        case 4: return "含有此上传者标签的画廊将被过滤"
        case 5: return "此语言的画廊将被过滤"
        default: return ""
        }
    }
}

// MARK: - ViewModel

@Observable
class FilterViewModel {
    var filters: [FilterRecord] = []

    func loadFilters() {
        do {
            filters = try EhDatabase.shared.getAllFilters()
        } catch {
            print("Failed to load filters: \(error)")
        }
    }

    func addFilter(text: String, mode: Int) {
        let record = FilterRecord(mode: mode, text: text, enable: true)
        do {
            try EhDatabase.shared.insertFilter(record)
            loadFilters()
        } catch {
            print("Failed to add filter: \(error)")
        }
    }

    func toggleFilter(_ filter: FilterRecord) {
        guard let id = filter.id else { return }
        do {
            // 简单地删除并重新插入以切换状态
            try EhDatabase.shared.deleteFilter(id: id)
            var newFilter = filter
            newFilter.enable.toggle()
            newFilter.id = nil
            try EhDatabase.shared.insertFilter(newFilter)
            loadFilters()
        } catch {
            print("Failed to toggle filter: \(error)")
        }
    }

    func deleteEnabled(at offsets: IndexSet) {
        let enabledFilters = filters.filter { $0.enable }
        for index in offsets {
            guard let id = enabledFilters[index].id else { continue }
            do {
                try EhDatabase.shared.deleteFilter(id: id)
            } catch {
                print("Failed to delete filter: \(error)")
            }
        }
        loadFilters()
    }

    func deleteDisabled(at offsets: IndexSet) {
        let disabledFilters = filters.filter { !$0.enable }
        for index in offsets {
            guard let id = disabledFilters[index].id else { continue }
            do {
                try EhDatabase.shared.deleteFilter(id: id)
            } catch {
                print("Failed to delete filter: \(error)")
            }
        }
        loadFilters()
    }
}

#Preview {
    NavigationStack {
        FilterView()
    }
}
