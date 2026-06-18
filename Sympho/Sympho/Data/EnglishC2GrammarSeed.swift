//
//  EnglishC2GrammarSeed.swift
//  Sympho
//

import Foundation
import SwiftData

enum EnglishC2GrammarSeed {
    private static let seedKey = "englishC2GrammarSeedVersion"
    private static let seedVersion = 1
    private static let domainTitle = "English C2"
    private static let trackTitle = "Grammar Track"

    static func runIfNeeded(in context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: seedKey) < seedVersion else { return }

        do {
            let domain = try ensureDomain(in: context)
            let track = ensureGrammarTrack(in: domain, context: context)
            seedModules(in: track, context: context)

            domain.updatedAt = Date()
            domain.isSynced = false
            track.updatedAt = Date()
            track.isSynced = false

            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
        } catch {
            print("Could not seed English C2 grammar track: \(error.localizedDescription)")
        }
    }

    private static func ensureDomain(in context: ModelContext) throws -> Domain {
        let domains = try context.fetch(FetchDescriptor<Domain>())
        if let existing = domains.first(where: { $0.title == domainTitle && !$0.isDeletedLocally }) {
            return existing
        }

        let nextIndex = domains.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let domain = Domain(
            title: domainTitle,
            desc: "Advanced English study space for C2 grammar, syntax, flow, and native-level structure.",
            colorHex: "#1F4D3A",
            iconName: DomainIcon.book.rawValue,
            sortIndex: nextIndex
        )
        context.insert(domain)
        return domain
    }

    private static func ensureGrammarTrack(in domain: Domain, context: ModelContext) -> Track {
        if let existing = domain.tracks.first(where: { $0.title == trackTitle && !$0.isDeletedLocally }) {
            return existing
        }

        let nextIndex = domain.tracks.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let track = Track(
            title: trackTitle,
            desc: "C2 grammar syllabus built from the English C2 Notion dropdowns.",
            sortIndex: nextIndex,
            domain: domain
        )
        context.insert(track)
        domain.tracks.append(track)
        return track
    }

    private static func seedModules(in track: Track, context: ModelContext) {
        for (moduleIndex, seed) in modules.enumerated() {
            let module = ensureModule(seed, at: moduleIndex, in: track, context: context)
            seedNodes(seed.nodes, in: module, context: context)
        }
    }

    private static func ensureModule(_ seed: ModuleSeed, at index: Int, in track: Track, context: ModelContext) -> Module {
        if let existing = track.modules.first(where: { $0.title == seed.title && !$0.isDeletedLocally }) {
            return existing
        }

        let module = Module(title: seed.title, desc: seed.desc, sortIndex: index, track: track)
        context.insert(module)
        track.modules.append(module)
        return module
    }

    private static func seedNodes(_ seeds: [NodeSeed], in module: Module, context: ModelContext) {
        for (nodeIndex, seed) in seeds.enumerated() {
            guard !module.nodes.contains(where: { $0.title == seed.title && !$0.isDeletedLocally }) else {
                continue
            }

            let node = Node(
                title: seed.title,
                desc: seed.desc,
                sortIndex: nodeIndex,
                status: .backlog,
                priority: .normal,
                captureIntent: .learningNode,
                module: module
            )
            context.insert(node)
            module.nodes.append(node)
        }
    }

    private struct ModuleSeed {
        let title: String
        let desc: String
        let nodes: [NodeSeed]
    }

    private struct NodeSeed {
        let title: String
        let desc: String
    }

    private static let modules: [ModuleSeed] = [
        ModuleSeed(
            title: "Tenses",
            desc: "C2 control of time, aspect, narrative distance, and tense shifting.",
            nodes: [
                NodeSeed(title: "Perfect aspect for perspective", desc: "Use present, past, and future perfect to place events relative to the speaker's current viewpoint."),
                NodeSeed(title: "Progressive aspect for framing", desc: "Choose progressive forms to show temporary states, developing actions, irritation, and background process."),
                NodeSeed(title: "Future forms and certainty", desc: "Contrast will, be going to, present continuous, present simple, and future perfect with their pragmatic meanings."),
                NodeSeed(title: "Narrative tense shifting", desc: "Move between past simple, past perfect, and historic present without confusing chronology."),
                NodeSeed(title: "Habitual past and present patterns", desc: "Control used to, would, keep -ing, tend to, and will for habits, routines, and characteristic behavior.")
            ]
        ),
        ModuleSeed(
            title: "Articles & Nouns",
            desc: "Precision with definiteness, abstraction, countability, and noun phrase packaging.",
            nodes: [
                NodeSeed(title: "Definite vs. indefinite reference", desc: "Decide when the reader can identify the noun and when a new instance is being introduced."),
                NodeSeed(title: "Zero article with abstract nouns", desc: "Use no article for broad concepts while switching to the for specified versions of those concepts."),
                NodeSeed(title: "Countable and uncountable shifts", desc: "Recognize nouns that change meaning when counted, such as experience, paper, room, and work."),
                NodeSeed(title: "Generic reference patterns", desc: "Compare a/an, the, plural zero article, and mass nouns for general statements."),
                NodeSeed(title: "Dense noun phrases", desc: "Build long noun phrases with classifiers, compounds, postmodifiers, and appositive detail.")
            ]
        ),
        ModuleSeed(
            title: "Conditionals",
            desc: "Real, unreal, mixed, implied, and rhetorical condition structures.",
            nodes: [
                NodeSeed(title: "Mixed conditionals", desc: "Connect past causes to present results, and present conditions to past outcomes."),
                NodeSeed(title: "Inverted conditionals", desc: "Use had, were, and should inversion for formal or compressed conditional meaning."),
                NodeSeed(title: "Implied conditions", desc: "Read and produce conditionals hidden inside phrases like otherwise, but for, without, and given."),
                NodeSeed(title: "Alternatives to if", desc: "Use unless, provided that, as long as, supposing, in case, and on condition that precisely."),
                NodeSeed(title: "Rhetorical and pragmatic conditionals", desc: "Use conditionals for politeness, criticism, negotiation, threats, and distancing.")
            ]
        ),
        ModuleSeed(
            title: "Modals",
            desc: "Modal verbs and semi-modals for stance, probability, obligation, and social force.",
            nodes: [
                NodeSeed(title: "Degrees of certainty", desc: "Rank must, may, might, could, can't, should, and will for probability and inference."),
                NodeSeed(title: "Past modal meanings", desc: "Control must have, might have, could have, should have, and needn't have for inference and judgment."),
                NodeSeed(title: "Obligation and advisability", desc: "Distinguish must, have to, should, ought to, be supposed to, and had better."),
                NodeSeed(title: "Permission and social distance", desc: "Use can, could, may, might, and would to calibrate politeness and authority."),
                NodeSeed(title: "Modal idioms and semi-modals", desc: "Handle be bound to, be likely to, be meant to, dare, need, and manage to.")
            ]
        ),
        ModuleSeed(
            title: "Sentence Architecture",
            desc: "Advanced sentence shape: emphasis, information order, compression, and balance.",
            nodes: [
                NodeSeed(title: "Information structure", desc: "Place old information before new information and control sentence end weight."),
                NodeSeed(title: "Cleft and pseudo-cleft sentences", desc: "Use it-clefts and what-clefts to focus attention and correct assumptions."),
                NodeSeed(title: "Inversion for emphasis", desc: "Use negative adverbial and fronted structure inversion accurately."),
                NodeSeed(title: "Parallelism and balance", desc: "Build coordinated structures that sound deliberate, clean, and rhetorically strong."),
                NodeSeed(title: "Compression with participles", desc: "Use reduced clauses and participle phrases without creating dangling modifiers.")
            ]
        ),
        ModuleSeed(
            title: "Prepositions & Phrasal Logic",
            desc: "Prepositions as meaning systems, not translations.",
            nodes: [
                NodeSeed(title: "Core spatial metaphors", desc: "Map at, on, in, over, under, through, across, and along from space into abstract meaning."),
                NodeSeed(title: "Dependent prepositions", desc: "Learn adjective, noun, and verb patterns such as responsible for, interest in, and object to."),
                NodeSeed(title: "Phrasal verb particles", desc: "Understand how up, out, off, down, through, and over alter verb meaning."),
                NodeSeed(title: "Prepositional phrase placement", desc: "Place prepositional phrases to avoid ambiguity and improve rhythm."),
                NodeSeed(title: "Preposition traps at C2", desc: "Separate near-synonyms such as by vs. with, for vs. to, of vs. from, and in vs. within.")
            ]
        ),
        ModuleSeed(
            title: "Verb Patterns (Gerunds vs. Infinitives)",
            desc: "Verb complementation and meaning shifts after common C2 verbs.",
            nodes: [
                NodeSeed(title: "Gerund vs. infinitive meaning shifts", desc: "Contrast remember doing/to do, stop doing/to do, try doing/to do, and regret doing/to say."),
                NodeSeed(title: "Object plus infinitive patterns", desc: "Use persuade someone to, enable someone to, force someone to, and allow someone to."),
                NodeSeed(title: "Bare infinitives", desc: "Use make, let, help, modal verbs, and perception verbs with bare infinitive patterns."),
                NodeSeed(title: "Preposition plus gerund", desc: "Recognize that verbs and adjectives followed by prepositions usually take gerunds."),
                NodeSeed(title: "Reporting verb patterns", desc: "Control suggest, recommend, deny, admit, warn, accuse, insist, and claim with correct complements.")
            ]
        ),
        ModuleSeed(
            title: "Collocations & Lexical Pairings",
            desc: "Native-like combinations across verbs, nouns, adjectives, adverbs, and fixed phrases.",
            nodes: [
                NodeSeed(title: "Verb-noun collocations", desc: "Use high-frequency pairings such as raise concerns, draw conclusions, reach consensus, and pose a risk."),
                NodeSeed(title: "Adjective-noun precision", desc: "Choose natural pairings such as heavy rain, strong evidence, rough estimate, and key constraint."),
                NodeSeed(title: "Adverb-adjective pairings", desc: "Use deeply flawed, highly unlikely, painfully obvious, and broadly consistent with proper register."),
                NodeSeed(title: "Academic and professional bundles", desc: "Learn phrase frames like in light of, with respect to, broadly speaking, and the extent to which."),
                NodeSeed(title: "Register-sensitive collocations", desc: "Distinguish formal, neutral, and conversational pairings so strong language does not sound odd.")
            ]
        ),
        ModuleSeed(
            title: "Adjectives, Adverbs & Intensifiers",
            desc: "Modification, grading, stance, and emphasis beyond simple very.",
            nodes: [
                NodeSeed(title: "Gradable vs. non-gradable adjectives", desc: "Use very, absolutely, completely, fairly, and utterly with compatible adjective types."),
                NodeSeed(title: "Stance adverbs", desc: "Control apparently, arguably, admittedly, frankly, technically, and presumably."),
                NodeSeed(title: "Adverb position and scope", desc: "Place adverbs so they modify the intended verb, adjective, clause, or whole sentence."),
                NodeSeed(title: "Intensifier register", desc: "Choose highly, deeply, wildly, seriously, super, way, and utterly by context."),
                NodeSeed(title: "Mitigation and hedging", desc: "Use somewhat, rather, fairly, almost, kind of, and not exactly to soften claims.")
            ]
        ),
        ModuleSeed(
            title: "Cohesion & Flow",
            desc: "Make sentences and paragraphs move with logic, rhythm, contrast, and reference.",
            nodes: [
                NodeSeed(title: "Reference chains", desc: "Use pronouns, demonstratives, synonyms, and repeated keywords to keep readers oriented."),
                NodeSeed(title: "Logical connectors", desc: "Use however, therefore, meanwhile, nevertheless, in contrast, and as a result without overloading prose."),
                NodeSeed(title: "Theme-rheme progression", desc: "Start from known context and end with new information to create flow."),
                NodeSeed(title: "Paragraph transitions", desc: "Bridge ideas using contrast, continuation, concession, cause, result, and summary moves."),
                NodeSeed(title: "Ellipsis and substitution", desc: "Use do so, one/ones, neither, so, not, and omitted repeated material for tighter writing.")
            ]
        ),
        ModuleSeed(
            title: "Clauses & Conjunctions (The Wiring)",
            desc: "Clause linking, subordination, reduction, and sentence logic.",
            nodes: [
                NodeSeed(title: "Relative clauses", desc: "Control defining, non-defining, reduced, sentential, and preposition-fronted relative clauses."),
                NodeSeed(title: "Adverbial clauses", desc: "Use time, reason, concession, contrast, purpose, condition, and result clauses."),
                NodeSeed(title: "Nominal clauses", desc: "Use that-clauses, wh-clauses, whether/if clauses, and embedded questions."),
                NodeSeed(title: "Concession and contrast", desc: "Choose although, even though, whereas, while, despite, in spite of, and nevertheless."),
                NodeSeed(title: "Clause reduction", desc: "Reduce clauses with -ing, -ed, infinitive, and verbless structures while keeping the subject clear.")
            ]
        ),
        ModuleSeed(
            title: "Conversational Syntax (The Native Override)",
            desc: "Permanent spoken-grammar patterns that make advanced English sound natural.",
            nodes: [
                NodeSeed(title: "Conversational deletion", desc: "Drop obvious subjects and auxiliaries in context: Going to the meeting? Sounds good. Gotta go."),
                NodeSeed(title: "Fronting and tails", desc: "Move topics forward or tag them at the end for spoken emphasis: This architecture, it's a nightmare. He's smart, your brother."),
                NodeSeed(title: "Connected speech and assimilation", desc: "Recognize fusions such as tell 'em, ask 'er, shoulda, musta, whatcha, and lemme."),
                NodeSeed(title: "Structural intensifiers and suffixes", desc: "Use -ish, -ass, super, and way to soften, approximate, or intensify in informal contexts."),
                NodeSeed(title: "Native discourse markers", desc: "Use like, you know, I mean, and well for pacing, softening, repair, and listener alignment."),
                NodeSeed(title: "Rule-breaks for emphasis", desc: "Recognize deliberate forms like ain't and double negatives when used for irony, comedy, or finality.")
            ]
        )
    ]
}
