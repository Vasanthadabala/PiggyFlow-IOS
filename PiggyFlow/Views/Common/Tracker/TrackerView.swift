//
//  TrackerView.swift
//  PiggyFlow
//
//  Created by Vasanth on 06/04/26.
//

import SwiftUI
import Foundation
import SwiftData

struct TrackerView: View {
    private static let brandfetchClientID = "1idb3QiwFiyjBHINpgC"

    enum TrackMode: String, CaseIterable {
        case subscriptions = "Subscriptions"
        case emi = "EMI"

        var formTypeLabel: String {
            switch self {
            case .subscriptions: return "subscription"
            case .emi: return "emi"
            }
        }

        var storageType: String {
            self == .subscriptions ? "subscription" : "emi"
        }

        static func from(storageType: String) -> TrackMode {
            storageType.lowercased() == "emi" ? .emi : .subscriptions
        }
    }

    @Environment(\.modelContext) private var context
    @Query private var trackerRecords: [TrackerRecord]

    @State private var selectedMode: TrackMode = .subscriptions
    @State private var editingRecordID: String?

    @State private var showAddSheet = false
    @State private var formType: TrackMode = .subscriptions
    @State private var formName = ""
    @State private var formSubType = "monthly"
    @State private var formAmount = ""
    @State private var formDate = Date()
    @State private var showSubTypeDropdown = false

    private var filteredRecords: [TrackerRecord] {
        trackerRecords
            .filter { TrackMode.from(storageType: $0.type) == selectedMode }
            .sorted { $0.dueDate > $1.dueDate }
    }

    private var monthlyTotal: Double {
        filteredRecords.reduce(0) { $0 + $1.amount }
    }

    private var yearlyTotal: Double {
        monthlyTotal * 12
    }

    private var canAdd: Bool {
        !formName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && Double(formAmount) != nil
        && (Double(formAmount) ?? 0) > 0
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    modePicker

                    Text(selectedMode.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black.opacity(0.9))

                    VStack(spacing: 8) {
                        Text("₹ \(monthlyTotal, specifier: "%.2f")")
                            .font(.system(size: 32, weight: .bold))
                        Text("per month")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.gray)
                        Text("\(filteredRecords.count) active  ·  ₹ \(yearlyTotal, specifier: "%.2f") / year")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.gray)
                    }

                    HStack {
                        Text(selectedMode.rawValue)
                            .font(.system(size: 24, weight: .semibold))
                        Spacer()
                    }

                    if filteredRecords.isEmpty {
                        emptyState
                            .padding(.top, 72)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredRecords) { record in
                                trackerCard(record)
                            }
                        }
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }

            Button {
                seedFormValues()
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(18)
                    .background(Circle().fill(Color.green))
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddSheet) {
            addSheet
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab(.subscriptions)
            modeTab(.emi)
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.gray.opacity(0.18)))
    }

    @ViewBuilder
    private func modeTab(_ mode: TrackMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 8) {
                if selectedMode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(mode.rawValue)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(selectedMode == mode ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selectedMode == mode ? Color.green : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "storefront")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.gray.opacity(0.45))

            Text(selectedMode == .emi ? "No EMI added yet" : "No subscription added yet")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.gray)

            Text(selectedMode == .emi ? "Tap the + button to add EMI data." : "Tap the + button to add subscription data.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.gray.opacity(0.6))
        }
    }

    @ViewBuilder
    private func trackerCard(_ record: TrackerRecord) -> some View {
        HStack(spacing: 12) {
            trackerAvatar(record)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(TrackMode.from(storageType: record.type) == .subscriptions ? "SUBSCRIPTION" : "EMI") · \(record.subType.capitalized)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.gray)
                Text("Due on \(record.dueDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }

            Spacer()

            Text("₹\(record.amount, specifier: "%.2f")")
                .font(.system(size: 14, weight: .bold))

            Menu {
                Button("Edit") {
                    beginEditing(record)
                }
                Button("Delete", role: .destructive) {
                    deleteItem(record)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.gray)
            }
            .menuStyle(.button)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.12)))
    }

    @ViewBuilder
    private func trackerAvatar(_ record: TrackerRecord) -> some View {
        if !record.logoUrl.isEmpty, let url = URL(string: record.logoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                default:
                    defaultAvatar(for: record)
                }
            }
        } else {
            defaultAvatar(for: record)
        }
    }

    private func defaultAvatar(for record: TrackerRecord) -> some View {
        Circle()
            .fill(Color.black)
            .frame(width: 40, height: 40)
            .overlay(
                Text(record.name.prefix(1).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.red)
            )
    }

    private var addSheet: some View {
        VStack(spacing:12) {
            HStack{
                Spacer()
                Button {
                    showAddSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.white, .red)
                        .padding()
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(editingRecordID == nil
                         ? (formType == .subscriptions ? "Add Subscription" : "Add EMI")
                         : (formType == .subscriptions ? "Edit Subscription" : "Edit EMI"))
                    .font(.system(size: 24, weight: .semibold))
                    
                    fieldTitle("Type")
                    Menu {
                        Button(TrackMode.subscriptions.formTypeLabel) { formType = .subscriptions }
                        Button(TrackMode.emi.formTypeLabel) { formType = .emi }
                    } label: {
                        menuField(formType.formTypeLabel)
                    }
                    .buttonStyle(.plain)
                    
                    fieldTitle("Name")
                    iconField(icon: "₹", placeholder: formType == .subscriptions ? "Subscription Name" : "EMI Name", text: $formName)
                    
                    fieldTitle("Sub Type")
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showSubTypeDropdown.toggle()
                            }
                        } label: {
                            HStack {
                                Text(formSubType)
                                Spacer()
                                Image(systemName: showSubTypeDropdown ? "chevron.up" : "chevron.down")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
                        }
                        .buttonStyle(.plain)

                        if showSubTypeDropdown {
                            VStack(spacing: 0) {
                                Button("monthly") {
                                    formSubType = "monthly"
                                    showSubTypeDropdown = false
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .buttonStyle(.plain)

                                Divider()

                                Button("yearly") {
                                    formSubType = "yearly"
                                    showSubTypeDropdown = false
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .buttonStyle(.plain)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                            )
                        }
                    }
                    
                    fieldTitle("Amount")
                    iconField(icon: "₹", placeholder: "Enter Amount", text: $formAmount)
                        .keyboardType(.decimalPad)
                    
                    fieldTitle("Date")
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.gray)
                            Text(formDate.formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(.system(size: 16, weight: .bold))
                        }
                        Spacer()
                        DatePicker("", selection: $formDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
                    
                    Button {
                        editingRecordID == nil ? addItem() : updateItem()
                    } label: {
                        Text(editingRecordID == nil ? "Add" : "Update")
                            .font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(canAdd ? Color.green : Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onTapGesture {
                showSubTypeDropdown = false
            }
        }
        .presentationDetents([.large])
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .medium))
    }

    private func menuField(_ value: String) -> some View {
        HStack {
            Text(value)
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundStyle(.primary.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))
    }

    private func iconField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.gray)
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }

    private func seedFormValues() {
        editingRecordID = nil
        formType = selectedMode
        formName = ""
        formSubType = "monthly"
        formAmount = ""
        formDate = Date()
    }

    private func beginEditing(_ record: TrackerRecord) {
        editingRecordID = record.id
        formType = TrackMode.from(storageType: record.type)
        formName = record.name
        formSubType = record.subType
        formAmount = String(format: "%.2f", record.amount)
        formDate = record.dueDate
        showAddSheet = true
    }

    private func addItem() {
        guard let amount = Double(formAmount), amount > 0 else { return }
        let trimmedName = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryLogoUrl = buildPrimaryBrandfetchUrl(companyName: trimmedName)

        let record = TrackerRecord(
            type: formType.storageType,
            name: trimmedName,
            subType: formSubType,
            amount: amount,
            dueDate: formDate,
            logoUrl: primaryLogoUrl
        )

        context.insert(record)
        do {
            try context.save()
            CloudSyncManager.shared.queueTrackerUpsert(record)
        } catch {
            print("❌ Failed to save tracker: \(error.localizedDescription)")
        }

        selectedMode = formType
        showAddSheet = false

        guard !primaryLogoUrl.isEmpty else { return }
        Task {
            if let fetched = await fetchBrandfetchLogoUrl(companyName: trimmedName) {
                await MainActor.run {
                    if record.logoUrl != fetched {
                        record.logoUrl = fetched
                        do {
                            try context.save()
                            CloudSyncManager.shared.queueTrackerUpsert(record)
                        } catch {
                            print("❌ Failed to update tracker logo: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func updateItem() {
        guard let id = editingRecordID,
              let amount = Double(formAmount),
              amount > 0,
              let record = trackerRecords.first(where: { $0.id == id }) else { return }

        let trimmedName = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryLogoUrl = buildPrimaryBrandfetchUrl(companyName: trimmedName)

        record.type = formType.storageType
        record.name = trimmedName
        record.subType = formSubType
        record.amount = amount
        record.dueDate = formDate
        record.logoUrl = primaryLogoUrl
        do {
            try context.save()
            CloudSyncManager.shared.queueTrackerUpsert(record)
        } catch {
            print("❌ Failed to update tracker: \(error.localizedDescription)")
        }

        selectedMode = formType
        showAddSheet = false

        guard !primaryLogoUrl.isEmpty else { return }
        Task {
            if let fetched = await fetchBrandfetchLogoUrl(companyName: trimmedName) {
                await MainActor.run {
                    if record.logoUrl != fetched {
                        record.logoUrl = fetched
                        do {
                            try context.save()
                            CloudSyncManager.shared.queueTrackerUpsert(record)
                        } catch {
                            print("❌ Failed to update tracker logo: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func deleteItem(_ record: TrackerRecord) {
        let id = record.id
        context.delete(record)
        do {
            try context.save()
            CloudSyncManager.shared.queueDeleteTracker(id: id)
        } catch {
            print("❌ Failed to delete tracker: \(error.localizedDescription)")
        }
    }

    private func fetchBrandfetchLogoUrl(companyName: String) async -> String? {
        let normalized = normalizeCompanyName(companyName)
        guard !normalized.isEmpty else { return nil }
        let domains = candidateDomains(for: normalized)
        guard !domains.isEmpty else { return nil }

        let candidates = domains.flatMap { domain in
            [
                "https://cdn.brandfetch.io/domain/\(domain)?c=\(Self.brandfetchClientID)",
                "https://cdn.brandfetch.io/\(domain)/icon?c=\(Self.brandfetchClientID)"
            ]
        }

        for url in candidates {
            if await isReachableImage(urlString: url) {
                return url
            }
        }
        return nil
    }

    private func buildPrimaryBrandfetchUrl(companyName: String) -> String {
        let normalized = normalizeCompanyName(companyName)
        guard !normalized.isEmpty else { return "" }
        guard let primaryDomain = candidateDomains(for: normalized).first else { return "" }
        return "https://cdn.brandfetch.io/domain/\(primaryDomain)?c=\(Self.brandfetchClientID)"
    }

    private func normalizeCompanyName(_ companyName: String) -> String {
        let lower = companyName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty { return "" }

        let replaced = lower.replacingOccurrences(
            of: "[^a-z0-9 ]",
            with: " ",
            options: .regularExpression
        )

        return replaced
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveKnownBrandDomain(normalizedCompanyName: String) -> String? {
        let directDomainMap: [(String, String)] = [
            ("amazon prime", "primevideo.com"),
            ("prime video", "primevideo.com"),
            ("vodafone", "myvi.in"),
            ("google", "google.com"),
            ("youtube", "youtube.com"),
            ("spotify", "spotify.com"),
            ("netflix", "netflix.com"),
            ("amazon", "amazon.com"),
            ("chatgpt", "openai.com"),
            ("openai", "openai.com"),
            ("hotstar", "hotstar.com"),
            ("jio", "jio.com"),
            ("airtel", "airtel.in"),
            ("adobe", "adobe.com"),
            ("microsoft", "microsoft.com"),
            ("apple", "apple.com"),
            ("hdfc", "hdfcbank.com"),
            ("icici", "icicibank.com"),
            ("sbi", "sbi.co.in"),
            ("axis", "axisbank.com"),
            ("tesla", "tesla.com"),
            ("toyota", "toyota.com"),
            ("honda", "honda.com"),
            ("hyundai", "hyundai.com"),
            ("kia", "kia.com"),
            ("mahindra", "mahindra.com"),
            ("tata", "tatamotors.com"),
            ("suzuki", "suzuki.com"),
            ("vi", "myvi.in")
        ]

        for (key, domain) in directDomainMap {
            if key == "vi" {
                if normalizedCompanyName.split(separator: " ").contains("vi") {
                    return domain
                }
            } else if normalizedCompanyName.contains(key) {
                return domain
            }
        }

        return nil
    }

    private func candidateDomains(for normalizedCompanyName: String) -> [String] {
        var domains: [String] = []

        if let mapped = resolveKnownBrandDomain(normalizedCompanyName: normalizedCompanyName) {
            domains.append(mapped)
        }

        let tokens = normalizedCompanyName.split(separator: " ").map(String.init)
        let compact = tokens.joined()
        let dashed = tokens.joined(separator: "-")
        let firstToken = tokens.first ?? compact

        let stems = [compact, dashed, firstToken].filter { !$0.isEmpty }
        let tlds = ["com", "in", "co.in", "io", "net", "org", "app"]

        for stem in stems {
            for tld in tlds {
                domains.append("\(stem).\(tld)")
            }
        }

        var seen = Set<String>()
        return domains.filter { seen.insert($0).inserted }
    }

    private func isReachableImage(urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            return (200...299).contains(http.statusCode) && contentType.starts(with: "image")
        } catch {
            return false
        }
    }
}

#Preview {
    TrackerView()
}
