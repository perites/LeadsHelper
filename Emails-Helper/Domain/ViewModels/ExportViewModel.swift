//
//  ExportViewModel.swift
//  Emails-Helper
//
//  Created by Mykyta Krementar on 21/10/2025.
//

import SwiftUI

struct ExportRequest: Codable {
    let fileName: String
    let folderName: String
    let isSeparateFiles: Bool
    let tags: [TagRequest]

    var jsonString: String {
        let jsonTagsRequests = try? JSONEncoder().encode(self)
        let jsonStringTagsRequests = String(
            data: jsonTagsRequests ?? Data(),
            encoding: .utf8
        )!

        return jsonStringTagsRequests
    }

    var tagsJsonString: String {
        let jsonTagsRequests = try? JSONEncoder().encode(tags)
        let jsonStringTagsRequests = String(
            data: jsonTagsRequests ?? Data(),
            encoding: .utf8
        )!

        return jsonStringTagsRequests
    }
}

struct TagRequest: Identifiable, Codable, CustomStringConvertible {
    var id = UUID()
    let tagId: Int64
    let tagName: String
    let tagCount: Int

    var requestedAmount: Int?
    var emails: [String] = []
    var emailCount: Int?

    init(tagId: Int64, tagName: String, tagCount: Int, requestedAmount: Int? = nil, emails: [String] = [], emailCount: Int? = nil) {
        self.tagId = tagId
        self.tagName = tagName
        self.tagCount = tagCount
        self.requestedAmount = requestedAmount
        self.emails = emails
        self.emailCount = emailCount
    }

    enum CodingKeys: String, CodingKey {
        case id, tagId, tagName, tagCount, requestedAmount
        case emailCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tagId, forKey: .tagId)
        try container.encode(tagName, forKey: .tagName)
        try container.encode(tagCount, forKey: .tagCount)
        try container.encode(requestedAmount, forKey: .requestedAmount)
        try container.encode(emails.count, forKey: .emailCount)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tagId = try container.decode(Int64.self, forKey: .tagId)
        tagName = try container.decode(String.self, forKey: .tagName)
        tagCount = try container.decode(Int.self, forKey: .tagCount)
        requestedAmount = try container.decodeIfPresent(Int.self, forKey: .requestedAmount)
        emailCount = try container.decodeIfPresent(Int.self, forKey: .emailCount)
        emails = []
    }

    var description: String {
        return "\(tagName)_\(formatNumber(requestedAmount ?? 0))"
    }

    func formatNumber(_ num: Int) -> String {
        let formatted: String
        switch num {
        case 1_000_000...:
            formatted = String(format: "%.1fM", Double(num) / 1_000_000)
        case 1_000...:
            formatted = String(format: "%.1fk", Double(num) / 1_000)
        default:
            formatted = "\(num)"
        }
        return formatted.replacingOccurrences(of: ".0", with: "")
    }
}

class ExportViewModel: ObservableObject {
    @Published var tagsRequests: [TagRequest]

    @Published var fileName: String
    @Published var folderName: String
    @Published var isSeparateFiles: Bool

    @ObservedObject var domain: DomainViewModel

    let allMergeTags: [String] = [
        "%d-name%",
        "%d-abrr%",
        "%day%",
        "%month%",
        "%t-all%",
        "%t-name%",
        "%t-amount%",
    ]

    var stringTagsRequests: String {
        tagsRequests
            .filter { $0.requestedAmount ?? 0 > 0 }
            .map(\.description)
            .joined(separator: "--")
    }

    init(domain: DomainViewModel) {
        _domain = .init(initialValue: domain)

        _fileName = .init(
            initialValue: domain.lastExportRequest?.fileName
                .components(separatedBy: "$|-|-|$")[safe: 1] ?? "%d-abrr% - %day%.%month% - %t-name%"
        )
        _folderName = .init(initialValue: domain.lastExportRequest?.folderName.components(separatedBy: "$|-|-|$")[safe: 1]  ?? "%d-abrr% - %day%.%month%")
        
        _isSeparateFiles = .init(initialValue: domain.lastExportRequest?.isSeparateFiles ?? false)

        _tagsRequests = .init(initialValue:
            domain.tagsInfo.map { tag in
                let previous = domain.lastExportRequest?.tags.first {
                    $0.tagId == tag.id
                }

                return TagRequest(
                    tagId: tag.id,
                    tagName: tag.name,
                    tagCount: tag.availableLeadsCount ?? 0,
                    requestedAmount: previous?.requestedAmount,
                    emailCount: previous?.emailCount ?? 0
                )
            }
        )
    }

    func applyMergeTags(to template: String, with tagRequest: TagRequest? = nil) -> String {
        let mergeTags = [
            "%d-name%": domain.name,
            "%d-abrr%": domain.abbreviation,
            "%day%": String(Calendar.current.component(.day, from: Date())),
            "%month%": String(Calendar.current.component(.month, from: Date())),
            "%t-all%": stringTagsRequests,
            "%t-name%": tagRequest?.tagName ?? "TestTag",
            "%t-amount%": tagRequest?.formatNumber(tagRequest!.requestedAmount ?? 0) ?? "2.5k",
        ]

        var result = template
        for (key, value) in mergeTags {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
    }

    enum ExportResult {
        case noFolder
        case failure
        case success
    }

    func exportLeads() async -> ExportResult {
        guard let folder = domain.saveFolder else {
            print("Choose a save folder first")
            return .noFolder
        }

        let fulfilledTagsRequests = await fulfillTagsRequests()

        tagsRequests = fulfilledTagsRequests

        if isSeparateFiles {
            for tagRequest in tagsRequests {
                guard let requestedAmount = tagRequest.requestedAmount, requestedAmount > 0 else {
                    continue
                }

                let caluculatedFolderName = applyMergeTags(
                    to: folderName,
                    with: tagRequest
                )

                let calculatedfileName = applyMergeTags(
                    to: fileName,
                    with: tagRequest
                )

                let content = formatEmails(for: tagRequest.emails)

                let subfolder = folder.appendingPathComponent("\(caluculatedFolderName)/")
                ensureFolderExists(at: subfolder)

                let fileURL = subfolder.appendingPathComponent("\(calculatedfileName).csv")

                saveFile(content: content, path: fileURL)
            }

        } else {
            let calculatedfileName = applyMergeTags(to: fileName)

            var emails = tagsRequests.flatMap { $0.emails }
            emails.shuffle()
            let content = formatEmails(for: emails)
            let fileURL = folder.appendingPathComponent("\(calculatedfileName).csv")

            saveFile(content: content, path: fileURL)
        }

        let lastExportRequest = ExportRequest(
            fileName: "\(applyMergeTags(to: fileName))$|-|-|$\(fileName)",
            folderName: "\(applyMergeTags(to: folderName))$|-|-|$\(folderName)",
            isSeparateFiles: isSeparateFiles,
            tags: tagsRequests
        )

        await ExportTable.addExport(domainId: domain.id, exportRequest: lastExportRequest)

        return .success
    }

    func fulfillTagsRequests() async -> [TagRequest] {
        var fulfilledTagsRequests = tagsRequests

        for (index, tagRequest) in tagsRequests.enumerated() {
            let result = await LeadsTable.getEmails(
                tagId: tagRequest.tagId,
                domainId: domain.id,
                amount: tagRequest.requestedAmount ?? 0,
                domainUseLimit: domain.useLimit,
                globalUseLimit: domain.globalUseLimit,
            )

            fulfilledTagsRequests[index].emails = result
        }

        return fulfilledTagsRequests
    }

    func ensureFolderExists(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func formatEmails(for emails: [String]) -> String {
        switch domain.exportType {
        case 1:
            var strEmails = ""
            for email in emails {
                let domainAbbrivation = domain.abbreviation

                let row = "\(email), \(email.replacingOccurrences(of: "@", with: domainAbbrivation))\n"
                strEmails += row
            }

            let content = "Email Address,Subscriber Key\n" + strEmails
            return content

        case 2:
            var strEmails = ""
            for email in emails {
                let domainName = domain.name
                let domainAbbrivation = domain.abbreviation

                let row = "\(email), \(email + domainAbbrivation), \(domainName)\n"
                strEmails += row
            }

            let content = "email,customer_id,domain\n" + strEmails
            return content

        default:
            let strEmails = emails.joined(separator: "\n")
            let content = "Email\n" + strEmails
            return content
        }
    }

    private func saveFile(content: String, path: URL) {
        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
            print("File saved at: \(path.path)")
        } catch {
            print("Failed to save file: \(error)")
        }
    }
}



extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
