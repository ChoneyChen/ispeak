import Foundation

/// The source PDF is kept as structured chapters, grammar points and bilingual examples.
struct Curriculum: Codable, Hashable {
    let chapters: [Chapter]
    let supplements: [Supplement]

    var hasGuidePDF: Bool { Bundle.main.url(forResource: "Guide", withExtension: "pdf") != nil }
    func chapterCount(part: Int) -> Int { chapters.filter { $0.part == part }.count }
    var allGrammarPoints: [GrammarPoint] { chapters.flatMap(\.grammar) }
    var allSentences: [Sentence] { allGrammarPoints.flatMap(\.examples) }
    var grammarCount: Int { allGrammarPoints.count }
    var sentenceCount: Int { allSentences.count }

    static func load(bundle: Bundle = .main) throws -> Curriculum {
        guard let url = bundle.url(forResource: "curriculum", withExtension: "json") else {
            throw CurriculumError.missingResource
        }
        return try load(from: url)
    }

    static func load(from url: URL) throws -> Curriculum {
        let curriculum = try JSONDecoder().decode(Curriculum.self, from: Data(contentsOf: url))
        try curriculum.validate()
        return curriculum
    }

    func validate() throws {
        guard !chapters.isEmpty else { throw CurriculumError.emptyCurriculum }
        var chapterIDs = Set<Int>()
        var grammarIDs = Set<String>()
        var sentenceIDs = Set<String>()
        for chapter in chapters {
            guard chapterIDs.insert(chapter.id).inserted else {
                throw CurriculumError.duplicateID("chapter \(chapter.id)")
            }
            guard !chapter.grammar.isEmpty else { throw CurriculumError.emptyChapter(chapter.id) }
            for grammar in chapter.grammar {
                guard !grammar.id.isEmpty, grammarIDs.insert(grammar.id).inserted else {
                    throw CurriculumError.duplicateID(grammar.id)
                }
                guard !grammar.examples.isEmpty else { throw CurriculumError.emptyGrammar(grammar.id) }
                for sentence in grammar.examples {
                    guard !sentence.id.isEmpty, sentenceIDs.insert(sentence.id).inserted else {
                        throw CurriculumError.duplicateID(sentence.id)
                    }
                    guard !sentence.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !sentence.zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw CurriculumError.emptySentence(sentence.id)
                    }
                }
            }
        }
    }
}

struct Chapter: Codable, Hashable, Identifiable {
    let id: Int
    let part: Int
    let title: String
    let subtitle: String
    let shortTitle: String
    let questions: [String]
    let practice: String
    let startPage: Int
    let grammar: [GrammarPoint]
}

struct GrammarPoint: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let level: String
    let pattern: String
    let note: String
    let page: Int
    let examples: [Sentence]
}

struct Sentence: Codable, Hashable, Identifiable {
    let id: String
    let en: String
    let zh: String
    let kind: String
    var provenance: SentenceProvenance? = nil
    var isPracticeScenario: Bool { ["scenario", "hypothetical"].contains(provenance?.type ?? "") }
}

struct SentenceProvenance: Codable, Hashable {
    let type: String
    let factIds: [String]
}

struct Supplement: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let page: Int
    let body: String
}

enum CurriculumError: LocalizedError {
    case missingResource
    case emptyCurriculum
    case emptyChapter(Int)
    case emptyGrammar(String)
    case emptySentence(String)
    case duplicateID(String)

    var errorDescription: String? {
        switch self {
        case .missingResource: return "找不到课程文件 curriculum.json。"
        case .emptyCurriculum: return "课程没有可学习的章节。"
        case .emptyChapter(let id): return "章节 \(id) 没有语法点。"
        case .emptyGrammar(let id): return "语法点 \(id) 没有例句。"
        case .emptySentence(let id): return "例句 \(id) 缺少中文或英文。"
        case .duplicateID(let id): return "课程内容编号重复：\(id)。"
        }
    }
}
