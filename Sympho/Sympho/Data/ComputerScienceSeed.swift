//
//  ComputerScienceSeed.swift
//  Sympho
//
//  Curriculum based on OSSU (https://github.com/ossu/computer-science) and
//  Developer-Y CS video courses (https://github.com/Developer-Y/cs-video-courses).
//

import Foundation
import SwiftData

enum ComputerScienceSeed {
    private static let seedKey = "computerScienceSeedVersion"
    private static let seedVersion = 2
    private static let domainTitle = "Computer Science"
    private static let ossu = "https://github.com/ossu/computer-science"
    private static let videoCourses = "https://github.com/Developer-Y/cs-video-courses"

    static func runIfNeeded(in context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: seedKey) < seedVersion else { return }

        do {
            let domain = try ensureDomain(in: context)
            for trackSeed in tracks {
                let track = ensureTrack(trackSeed, in: domain, context: context)
                seedModules(trackSeed.modules, in: track, context: context)
            }
            for standalone in standaloneModules {
                let module = ensureStandaloneModule(standalone, in: domain, context: context)
                seedNodes(standalone.nodes, in: module, context: context)
            }

            domain.updatedAt = Date()
            domain.isSynced = false
            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
        } catch {
            print("Could not seed Computer Science curriculum: \(error.localizedDescription)")
        }
    }

    private static func ensureDomain(in context: ModelContext) throws -> Domain {
        let domains = try context.fetch(FetchDescriptor<Domain>())
        if let existing = domains.first(where: { $0.title == domainTitle && !$0.isDeletedLocally }) {
            return existing
        }
        throw NSError(domain: "ComputerScienceSeed", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Computer Science domain not found. Create it first in Sympho."
        ])
    }

    private static func ensureTrack(_ seed: TrackSeed, in domain: Domain, context: ModelContext) -> Track {
        if let existing = domain.tracks.first(where: { $0.title == seed.title && !$0.isDeletedLocally }) {
            return existing
        }
        let nextIndex = domain.tracks.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let track = Track(title: seed.title, desc: seed.desc, sortIndex: nextIndex, domain: domain)
        context.insert(track)
        domain.tracks.append(track)
        return track
    }

    private static func ensureStandaloneModule(_ seed: ModuleSeed, in domain: Domain, context: ModelContext) -> Module {
        if let existing = domain.modules.first(where: { $0.title == seed.title && !$0.isDeletedLocally }) {
            return existing
        }
        let nextIndex = domain.modules.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let module = Module(title: seed.title, desc: seed.desc, sortIndex: nextIndex, domain: domain)
        context.insert(module)
        domain.modules.append(module)
        return module
    }

    private static func seedModules(_ seeds: [ModuleSeed], in track: Track, context: ModelContext) {
        for (moduleIndex, seed) in seeds.enumerated() {
            let module = ensureModule(seed, at: moduleIndex, in: track, context: context)
            seedNodes(seed.nodes, in: module, context: context)
        }
    }

    private static func ensureModule(_ seed: ModuleSeed, at index: Int, in track: Track, context: ModelContext) -> Module {
        if let existing = track.modules.first(where: { $0.title == seed.title && !$0.isDeletedLocally }) {
            return existing
        }
        let nextIndex = track.modules.map(\.sortIndex).max().map { $0 + 1 } ?? index
        let module = Module(title: seed.title, desc: seed.desc, sortIndex: nextIndex, track: track)
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

    private struct TrackSeed {
        let title: String
        let desc: String
        let modules: [ModuleSeed]
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

    private static func ossuCourse(_ title: String, _ url: String, note: String = "") -> NodeSeed {
        let extra = note.isEmpty ? "" : "\n\(note)"
        return NodeSeed(title: title, desc: "OSSU (\(ossu))\(extra)\n\(url)")
    }

    private static func videoCourse(_ title: String, _ url: String, note: String = "") -> NodeSeed {
        let extra = note.isEmpty ? "" : "\n\(note)"
        return NodeSeed(title: title, desc: "CS Video Courses (\(videoCourses))\(extra)\n\(url)")
    }

    private static func concept(_ title: String, _ desc: String) -> NodeSeed {
        NodeSeed(title: title, desc: desc)
    }

    // MARK: - Standalone modules (enrich existing Git / Docker)

    private static let standaloneModules: [ModuleSeed] = [
        ModuleSeed(
            title: "Git. GItHub and Version Control",
            desc: "Version control workflows for solo and team software development.",
            nodes: [
                concept("Commits, branches, and merges", "Stage changes, branch safely, and resolve merge conflicts."),
                concept("Pull requests and code review", "Use PRs for quality control and collaborative development."),
                ossuCourse("The Missing Semester — Version Control", "https://missing.csail.mit.edu/2020/version-control/", note: "Git chapter"),
                videoCourse("Pro Git Book", "https://git-scm.com/book/en/v2", note: "Free reference")
            ]
        ),
        ModuleSeed(
            title: "Docker",
            desc: "Containers for reproducible development and deployment.",
            nodes: [
                concept("Images, containers, and Dockerfile", "Build immutable images and run isolated environments."),
                concept("Compose and local multi-service stacks", "Wire app, database, and cache services for local dev."),
                concept("Container networking and volumes", "Persist data and connect services across containers."),
                videoCourse("Docker Documentation — Get Started", "https://docs.docker.com/get-started/", note: "Official tutorial")
            ]
        )
    ]

    // MARK: - Tracks

    private static let tracks: [TrackSeed] = [
        TrackSeed(
            title: "Core CS",
            desc: "OSSU core curriculum — the required undergraduate CS backbone (intro through ethics).",
            modules: [
                ModuleSeed(
                    title: "Intro CS",
                    desc: "First exposure to computation, programming, and problem decomposition.",
                    nodes: [
                        concept("Computation and imperative programming", "Variables, control flow, functions, and basic data structures."),
                        ossuCourse("MIT 6.0001 — Intro CS and Python", "https://ocw.mit.edu/courses/6-0001-introduction-to-computer-science-and-programming-in-python-fall-2016/"),
                        videoCourse("Harvard CS50", "https://cs50.harvard.edu/x/"),
                        videoCourse("UC Berkeley CS61A", "https://cs61a.org/"),
                        videoCourse("MIT 6.00SC — Intro CS and Programming", "https://ocw.mit.edu/courses/6-00sc-introduction-to-computer-science-and-programming-spring-2011/")
                    ]
                ),
                ModuleSeed(
                    title: "Programming & Software Design",
                    desc: "Systematic design, multiple paradigms, OOP, and software architecture.",
                    nodes: [
                        concept("Functional and class-based design", "Data definitions, templates, and systematic program design."),
                        concept("Programming languages and OOP", "Static vs dynamic typing, ML-family and Lisp-family languages, object-oriented design."),
                        ossuCourse("Systematic Program Design (SPD)", "https://github.com/ossu/computer-science/tree/master/coursepages/spd"),
                        ossuCourse("Class-based Program Design", "https://github.com/ossu/computer-science/tree/master/coursepages/class-based"),
                        videoCourse("UW CSE 341 — Programming Languages", "https://courses.cs.washington.edu/courses/cse341/"),
                        ossuCourse("Object-Oriented Design — NEU CS3500", "https://course.ccs.neu.edu/cs3500f19/"),
                        ossuCourse("Software Architecture — Coursera", "https://www.coursera.org/learn/software-architecture"),
                        videoCourse("Stanford CS106B — Programming Abstractions", "https://see.stanford.edu/Course/CS106B")
                    ]
                ),
                ModuleSeed(
                    title: "Math for CS",
                    desc: "Calculus and discrete mathematics for algorithms and theory.",
                    nodes: [
                        concept("Discrete math and proofs", "Logic, sets, graphs, combinatorics, and proof techniques."),
                        concept("Probability and asymptotic notation", "Discrete probability and big-O analysis for algorithms."),
                        ossuCourse("MIT Calculus 1A — Differentiation", "https://openlearninglibrary.mit.edu/courses/course-v1:MITx+18.01.1x+2T2019/about"),
                        ossuCourse("MIT Calculus 1B — Integration", "https://openlearninglibrary.mit.edu/courses/course-v1:MITx+18.01.2x+3T2019/about"),
                        ossuCourse("MIT Calculus 1C — Series & Coordinates", "https://openlearninglibrary.mit.edu/courses/course-v1:MITx+18.01.3x+1T2020/about"),
                        ossuCourse("MIT 6.042J — Mathematics for Computer Science", "https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-fall-2010/")
                    ]
                ),
                ModuleSeed(
                    title: "Data Structures & Algorithms",
                    desc: "Core theory: sorting, graphs, dynamic programming, and NP-completeness.",
                    nodes: [
                        concept("Divide and conquer", "Recurrence relations, merge sort, and master theorem."),
                        concept("Graph algorithms", "BFS, DFS, shortest paths, and minimum spanning trees."),
                        concept("Dynamic programming and NP-completeness", "Memoization, optimal substructure, and hardness reductions."),
                        ossuCourse("Stanford Algorithms — Part 1", "https://www.edx.org/learn/algorithms/stanford-university-algorithms-design-and-analysis-part-1"),
                        ossuCourse("Stanford Algorithms — Part 2", "https://www.edx.org/learn/algorithms/stanford-university-algorithms-design-and-analysis-part-2"),
                        videoCourse("MIT 6.006 — Introduction to Algorithms", "https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/"),
                        videoCourse("Princeton COS 226 — Algorithms", "https://www.cs.princeton.edu/courses/archive/spr24/cos226/"),
                        videoCourse("UC Berkeley CS61B — Data Structures", "https://sp26.datastructur.es/")
                    ]
                ),
                ModuleSeed(
                    title: "Computer Systems",
                    desc: "From logic gates to operating systems and computer networks.",
                    nodes: [
                        concept("Computer architecture and assembly", "Boolean logic, memory, VMs, compilers, and machine language."),
                        concept("Operating systems", "Processes, threads, scheduling, virtual memory, and synchronization."),
                        concept("Computer networking", "Layered protocols, TCP/IP, and network application design."),
                        ossuCourse("Nand to Tetris — Part I", "https://www.nand2tetris.org/"),
                        ossuCourse("Nand to Tetris — Part II", "https://www.coursera.org/learn/nand2tetris2"),
                        ossuCourse("OSTEP — Operating Systems", "https://github.com/ossu/computer-science/tree/master/coursepages/ostep"),
                        videoCourse("OSTEP Book (free)", "https://pages.cs.wisc.edu/~remzi/OSTEP/"),
                        ossuCourse("Kurose & Ross — Computer Networking", "http://gaia.cs.umass.edu/kurose_ross/online_lectures.htm"),
                        videoCourse("UW CSE 451 — Introduction to Operating Systems", "https://courses.cs.washington.edu/courses/cse451/")
                    ]
                ),
                ModuleSeed(
                    title: "Databases",
                    desc: "Relational modeling, SQL, and semistructured data.",
                    nodes: [
                        concept("Relational modeling and normalization", "Schemas, keys, functional dependencies, and ER diagrams."),
                        concept("SQL and transactions", "Queries, indexes, ACID, and isolation levels."),
                        concept("Semistructured and NoSQL data", "JSON, XML, document stores, and when to denormalize."),
                        ossuCourse("Stanford DB — Modeling and Theory", "https://www.edx.org/learn/databases/stanford-university-databases-modeling-and-theory"),
                        ossuCourse("Stanford DB — Relational Databases and SQL", "https://www.edx.org/learn/relational-databases/stanford-university-databases-relational-databases-and-sql"),
                        ossuCourse("Stanford DB — Semistructured Data", "https://www.edx.org/learn/relational-databases/stanford-university-databases-semistructured-data"),
                        videoCourse("CMU 15-445 — Database Systems", "https://15445.courses.cs.cmu.edu/")
                    ]
                ),
                ModuleSeed(
                    title: "Security Fundamentals",
                    desc: "CIA triad, secure design, vulnerabilities, and defensive programming.",
                    nodes: [
                        concept("Threat modeling and secure design", "Confidentiality, integrity, availability, and attack surfaces."),
                        concept("Vulnerability classes", "Injection, memory corruption, auth flaws, and misconfiguration."),
                        ossuCourse("RIT Cybersecurity Fundamentals", "https://www.edx.org/learn/cybersecurity/rochester-institute-of-technology-cybersecurity-fundamentals"),
                        ossuCourse("Principles of Secure Coding", "https://www.coursera.org/learn/secure-coding-principles"),
                        ossuCourse("Identifying Security Vulnerabilities", "https://www.coursera.org/learn/identifying-security-vulnerabilities"),
                        ossuCourse("Security Vulnerabilities in C/C++", "https://www.coursera.org/learn/identifying-security-vulnerabilities-c-programming"),
                        videoCourse("Stanford CS253 — Web Security", "https://web.stanford.edu/class/cs253/")
                    ]
                ),
                ModuleSeed(
                    title: "Software Engineering",
                    desc: "Agile process, specifications, REST, and building sizable projects.",
                    nodes: [
                        concept("Requirements and specifications", "User stories, acceptance criteria, and API contracts."),
                        concept("Agile, testing, and refactoring", "Iterative delivery, test coverage, and technical debt."),
                        ossuCourse("UBC Software Engineering — Introduction", "https://www.edx.org/learn/software-engineering/university-of-british-columbia-software-engineering-introduction"),
                        videoCourse("MIT 6.031 — Software Construction", "https://web.mit.edu/6.031/www/"),
                        videoCourse("Berkeley CS169 — Software Engineering", "https://www.edx.org/learn/software-engineering/university-of-california-berkeley-software-as-a-service")
                    ]
                ),
                ModuleSeed(
                    title: "Ethics & Professional Practice",
                    desc: "Social context, IP, privacy, and engineering ethics.",
                    nodes: [
                        concept("Professional ethics in computing", "Responsibility, bias, accessibility, and societal impact."),
                        ossuCourse("Ethics, Technology and Engineering", "https://www.coursera.org/learn/ethics-technology-engineering"),
                        ossuCourse("Introduction to Intellectual Property", "https://www.coursera.org/learn/introduction-intellectual-property"),
                        ossuCourse("Data Privacy Fundamentals", "https://www.coursera.org/learn/northeastern-data-privacy")
                    ]
                ),
                ModuleSeed(
                    title: "CS Tools",
                    desc: "Shell, editors, and the missing semester of practical CS skills.",
                    nodes: [
                        concept("Shell scripting and command line", "Pipes, redirection, environment variables, and automation."),
                        concept("Editors and developer tooling", "Vim, debugging, and productivity workflows."),
                        ossuCourse("The Missing Semester of Your CS Education", "https://missing.csail.mit.edu/"),
                        concept("See also: Git and Docker standalone modules", "Version control and containers live as quick-access modules in this domain.")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "Backend, Servers & Infrastructure",
            desc: "Production backend engineering — APIs, databases, and distributed systems. For dedicated DevOps and architecture, see the Computer Architecture & DevOps track.",
            modules: [
                ModuleSeed(
                    title: "HTTP, APIs & Web Foundations",
                    desc: "HTTP semantics, REST, authentication, and API design.",
                    nodes: [
                        concept("HTTP methods, headers, and status codes", "Idempotency, caching, cookies, and content negotiation."),
                        concept("REST and API design", "Resources, versioning, pagination, and error contracts."),
                        concept("Authentication patterns", "Sessions, JWT, OAuth2, and API keys."),
                        videoCourse("MIT 6.824 — Distributed Systems (lectures)", "https://pdos.csail.mit.edu/6.824/schedule.html", note: "Also covers RPC and HTTP-based systems"),
                        videoCourse("FastAPI Documentation", "https://fastapi.tiangolo.com/learn/", note: "Modern Python API framework"),
                        videoCourse("Node.js Documentation — Guides", "https://nodejs.org/en/docs/guides")
                    ]
                ),
                ModuleSeed(
                    title: "Backend Languages & Services",
                    desc: "Building server applications with mainstream backend stacks.",
                    nodes: [
                        concept("Service layers and MVC", "Controllers, services, repositories, and dependency injection."),
                        concept("Validation, middleware, and error handling", "Request pipelines and consistent API responses."),
                        videoCourse("Stanford CS142 — Web Applications", "https://web.stanford.edu/class/cs142/"),
                        videoCourse("MIT 6.170 — Software Studio", "https://web.mit.edu/6.170/www/"),
                        videoCourse("Harvard CS50 Web", "https://cs50.harvard.edu/web/"),
                        videoCourse("Django Documentation", "https://docs.djangoproject.com/en/stable/"),
                        videoCourse("Spring Boot Guides", "https://spring.io/guides")
                    ]
                ),
                ModuleSeed(
                    title: "Databases in Production",
                    desc: "Running Postgres, Redis, migrations, and query performance in production.",
                    nodes: [
                        concept("Indexing and query plans", "B-trees, EXPLAIN, and avoiding N+1 queries."),
                        concept("Migrations and schema evolution", "Zero-downtime changes and backward compatibility."),
                        concept("Caching with Redis", "TTL, eviction, and cache-aside patterns."),
                        videoCourse("Use It or Lose It — Postgres", "https://www.postgresql.org/docs/current/tutorial.html", note: "Official tutorial"),
                        videoCourse("Redis University — Introduction", "https://university.redis.io/")
                    ]
                ),
                ModuleSeed(
                    title: "Distributed Systems",
                    desc: "Replication, consensus, microservices, and failure modes at scale.",
                    nodes: [
                        concept("CAP and consistency models", "Eventual consistency, linearizability, and tradeoffs."),
                        concept("Replication and consensus", "Leader election, Raft, and distributed transactions."),
                        concept("Microservices and message queues", "Service boundaries, async messaging, and sagas."),
                        videoCourse("MIT 6.824 — Distributed Systems", "https://pdos.csail.mit.edu/6.824/"),
                        videoCourse("CMU 15-440 — Distributed Systems", "https://www.cs.cmu.edu/~15-440/"),
                        videoCourse("Berkeley CS186 — Database Systems (distributed topics)", "https://cs186berkeley.net/")
                    ]
                ),
                ModuleSeed(
                    title: "Containers & Orchestration",
                    desc: "Docker in production and Kubernetes fundamentals.",
                    nodes: [
                        concept("Production container patterns", "Multi-stage builds, health checks, and resource limits."),
                        concept("Kubernetes primitives", "Pods, deployments, services, ingress, and config maps."),
                        videoCourse("Kubernetes Documentation — Concepts", "https://kubernetes.io/docs/concepts/"),
                        videoCourse("Docker Docs — Best practices", "https://docs.docker.com/develop/dev-best-practices/")
                    ]
                ),
                ModuleSeed(
                    title: "CI/CD & Observability",
                    desc: "Pipelines, logging, metrics, and tracing for running systems.",
                    nodes: [
                        concept("Continuous integration and delivery", "Automated tests, staging, and deployment gates."),
                        concept("Logs, metrics, and traces", "The three pillars of observability."),
                        videoCourse("GitHub Actions Documentation", "https://docs.github.com/en/actions"),
                        videoCourse("OpenTelemetry Documentation", "https://opentelemetry.io/docs/"),
                        videoCourse("Prometheus Getting Started", "https://prometheus.io/docs/introduction/first_steps/")
                    ]
                ),
                ModuleSeed(
                    title: "Cloud & Deployment",
                    desc: "Deploying services on cloud providers and managing infrastructure.",
                    nodes: [
                        concept("Cloud primitives", "Compute, storage, networking, IAM, and managed services."),
                        concept("Serverless and load balancing", "Lambda/functions, API gateways, and horizontal scaling."),
                        videoCourse("AWS Skill Builder — Cloud Practitioner", "https://skillbuilder.aws/"),
                        videoCourse("Google Cloud Skills Boost", "https://www.cloudskillsboost.google/"),
                        videoCourse("Hugging Face — TGI Inference", "https://github.com/huggingface/text-generation-inference", note: "LLM serving reference")
                    ]
                ),
                ModuleSeed(
                    title: "System Design",
                    desc: "Designing scalable systems — caching, queues, and architecture interviews.",
                    nodes: [
                        concept("Caching strategies", "CDN, application cache, and cache invalidation."),
                        concept("Load balancing and rate limiting", "Horizontal scale, backpressure, and circuit breakers."),
                        concept("Designing data-intensive apps", "Storage engines, stream processing, and reliability."),
                        videoCourse("Martin Kleppmann — Designing Data-Intensive Applications", "https://dataintensive.net/", note: "Book reference"),
                        videoCourse("MIT 6.033 — Computer Systems Engineering", "https://ocw.mit.edu/courses/6-033-computer-system-engineering-spring-2009/")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "C & C++ Systems Programming",
            desc: "Low-level systems languages — memory, pointers, performance, and close-to-the-metal programming.",
            modules: [
                ModuleSeed(
                    title: "C Programming",
                    desc: "Procedural C, manual memory, compilation, and systems fundamentals.",
                    nodes: [
                        concept("Pointers, arrays, and memory layout", "Stack vs heap, addresses, dereferencing, and buffer basics."),
                        concept("Structs, headers, and the build toolchain", "gcc/clang, make, headers, linkage, and compilation stages."),
                        concept("File I/O and POSIX basics", "stdio, file descriptors, and Unix system call surface."),
                        videoCourse("Stanford CS107 — Programming Paradigms (C)", "https://see.stanford.edu/Course/CS107"),
                        videoCourse("IIT Kanpur — Programming in C", "https://nptel.ac.in/courses/106104128/"),
                        videoCourse("UW Madison CS354 — Machine Organization and Programming", "https://www.youtube.com/playlist?list=PLXY5xcFHqg32r5MZ-HfpA2Tr8Ke2lDYwI"),
                        videoCourse("MIT 6.172 — Performance Engineering", "https://ocw.mit.edu/courses/6-172-performance-engineering-of-software-systems-fall-2018/"),
                        ossuCourse("Nand to Tetris (uses C-like HDL/Hacker)", "https://www.nand2tetris.org/", note: "Bridge from logic to low-level implementation")
                    ]
                ),
                ModuleSeed(
                    title: "C++ Programming",
                    desc: "Modern C++ — RAII, templates, STL, and systems-level OOP.",
                    nodes: [
                        concept("RAII and value semantics", "Constructors, destructors, move semantics, and resource ownership."),
                        concept("Templates and the STL", "Generic programming, containers, iterators, and algorithms."),
                        concept("Modern C++ features", "C++11/14/17/20: smart pointers, lambdas, constexpr, and ranges."),
                        videoCourse("Stanford CS106L — Standard C++ Programming", "https://web.stanford.edu/class/cs106l/"),
                        videoCourse("Stanford CS106X — Programming Abstractions in C++", "http://web.stanford.edu/class/cs106x/"),
                        videoCourse("TUM IN2377 — Concepts of C++ Programming", "https://live.rbg.tum.de/?year=2023&term=W&slug=cpp&view=3"),
                        videoCourse("TUM IN1503 — Advanced C++ Programming", "https://live.rbg.tum.de/?year=2023&term=W&slug=AdvProg&view=3"),
                        videoCourse("IIT Kharagpur — Programming in C++", "https://nptel.ac.in/courses/106105151/"),
                        videoCourse("University of Bonn — Modern C++", "https://www.youtube.com/playlist?list=PLgnQpQtFTOGRM59sr3nSL8BmeMZR9GCIA")
                    ]
                ),
                ModuleSeed(
                    title: "Memory, Assembly & Low-Level Debugging",
                    desc: "How C/C++ maps to machine code — assembly, gdb, valgrind, and undefined behavior.",
                    nodes: [
                        concept("Assembly and calling conventions", "Registers, stacks, frames, and how functions call each other."),
                        concept("Debugging native code", "gdb/lldb, breakpoints, watchpoints, and core dumps."),
                        concept("Memory safety and tooling", "Valgrind, AddressSanitizer, leaks, and undefined behavior."),
                        videoCourse("CMU 15-213 — Intro to Computer Systems", "https://www.cs.cmu.edu/~213/"),
                        videoCourse("Berkeley CS61C — Machine Structures", "https://cs61c.org/"),
                        videoCourse("Stanford CS107 — Debugging and systems labs", "https://see.stanford.edu/Course/CS107", note: "Companion to C paradigms course")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "Computer Architecture & DevOps",
            desc: "Hardware-to-software architecture and the DevOps toolchain — build, ship, run, and operate systems.",
            modules: [
                ModuleSeed(
                    title: "Computer Architecture",
                    desc: "Digital logic, CPU design, caches, pipelining, and how code runs on real hardware.",
                    nodes: [
                        concept("Digital logic and gates", "Boolean algebra, combinational and sequential logic, flip-flops."),
                        concept("CPU microarchitecture", "Instruction sets, pipelining, hazards, caches, and branch prediction."),
                        concept("Memory hierarchy", "Registers, L1/L2/L3, RAM, virtual memory, and TLBs."),
                        ossuCourse("MIT 6.004 — Computation Structures 1", "https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/"),
                        ossuCourse("MIT 6.004 — Computation Structures 2", "https://learning.edx.org/course/course-v1:MITx+6.004.2x+3T2015"),
                        ossuCourse("MIT 6.004 — Computation Structures 3", "https://learning.edx.org/course/course-v1:MITx+6.004.3x_2+1T2017"),
                        videoCourse("Berkeley CS61C — Great Ideas in Computer Architecture", "https://cs61c.org/"),
                        videoCourse("CMU 15-213 — Computer Systems", "https://www.cs.cmu.edu/~213/"),
                        videoCourse("UW CS354 — Machine Organization", "https://www.youtube.com/playlist?list=PLXY5xcFHqg32r5MZ-HfpA2Tr8Ke2lDYwI")
                    ]
                ),
                ModuleSeed(
                    title: "DevOps Engineering",
                    desc: "Culture and practice of shipping reliably — automation, pipelines, containers, and operations.",
                    nodes: [
                        concept("DevOps principles", "CI/CD, infrastructure as code, blameless postmortems, and DORA metrics."),
                        concept("Release engineering", "Blue/green, canary, feature flags, and rollback strategies."),
                        concept("On-call and incident response", "Runbooks, alerting, SLOs, and post-incident reviews."),
                        videoCourse("Google SRE Book", "https://sre.google/sre-book/table-of-contents/", note: "Free online"),
                        videoCourse("GitHub Actions — CI/CD", "https://docs.github.com/en/actions"),
                        videoCourse("Kubernetes — Production patterns", "https://kubernetes.io/docs/concepts/"),
                        videoCourse("Docker — Production handbook", "https://docs.docker.com/develop/dev-best-practices/"),
                        concept("See also: Backend track modules", "Containers & Orchestration, CI/CD & Observability, and Cloud & Deployment go deeper on each layer.")
                    ]
                ),
                ModuleSeed(
                    title: "Infrastructure as Code & Platform",
                    desc: "Terraform, Ansible, GitOps, and managing cloud infrastructure declaratively.",
                    nodes: [
                        concept("Infrastructure as Code", "Declarative configs, state, drift detection, and modules."),
                        concept("Configuration management", "Ansible/Chef patterns for server provisioning."),
                        concept("GitOps and platform engineering", "ArgoCD, internal developer platforms, and golden paths."),
                        videoCourse("Terraform Documentation — Tutorials", "https://developer.hashicorp.com/terraform/tutorials"),
                        videoCourse("Ansible Documentation — Getting Started", "https://docs.ansible.com/ansible/latest/getting_started/index.html"),
                        videoCourse("ArgoCD — GitOps", "https://argo-cd.readthedocs.io/en/stable/"),
                        videoCourse("AWS — Well-Architected Framework", "https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "App Development",
            desc: "Client and native application development — your specialization track.",
            modules: [
                ModuleSeed(
                    title: "Apple Native",
                    desc: "Swift, SwiftUI, and Apple platform fundamentals.",
                    nodes: [
                        concept("Swift language fundamentals", "Optionals, structs, protocols, and value semantics."),
                        concept("SwiftUI views and state", "Declarative UI, @State, @Binding, and navigation."),
                        concept("Xcode and Apple HIG", "Project structure, debugging, and human interface guidelines."),
                        concept("Concurrency with async/await", "Actors, structured concurrency, and MainActor."),
                        videoCourse("Apple — Develop in Swift Tutorials", "https://developer.apple.com/tutorials/develop-in-swift"),
                        videoCourse("Stanford CS193p — SwiftUI", "https://cs193p.sites.stanford.edu/")
                    ]
                ),
                ModuleSeed(
                    title: "Frameworks",
                    desc: "Apple frameworks beyond basic SwiftUI.",
                    nodes: [
                        concept("UIKit interoperability", "Bridging SwiftUI and UIKit where needed."),
                        concept("Combine and reactive patterns", "Publishers, subscribers, and data flow."),
                        concept("Core Data and persistence", "Local storage, migrations, and CloudKit sync."),
                        concept("Networking on Apple platforms", "URLSession, Codable, and background tasks."),
                        videoCourse("Apple Framework Documentation", "https://developer.apple.com/documentation/"),
                        videoCourse("Stanford CS194 — iOS Development", "https://cs194.sites.stanford.edu/")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "Advanced CS",
            desc: "OSSU advanced electives — depth in programming, systems, theory, security, and capstone.",
            modules: [
                ModuleSeed(
                    title: "Advanced Programming",
                    desc: "Compilers, parallel programming, functional languages, and testing.",
                    nodes: [
                        ossuCourse("Stanford Compilers", "https://www.edx.org/learn/computer-science/stanford-university-compilers"),
                        ossuCourse("Parallel Programming in Scala", "https://www.coursera.org/learn/scala-parallel-programming"),
                        ossuCourse("UPenn CIS194 — Introduction to Haskell", "https://www.seas.upenn.edu/~cis194/spring15/"),
                        ossuCourse("Learn Prolog Now", "https://www.learnprolognow.org/"),
                        videoCourse("Stanford CS143 — Compilers", "https://web.stanford.edu/class/cs143/"),
                        videoCourse("MIT 6.035 — Computer Language Engineering", "https://ocw.mit.edu/courses/6-035-computer-language-engineering-spring-2010/")
                    ]
                ),
                ModuleSeed(
                    title: "Advanced Systems",
                    desc: "Digital circuits, computer architecture, and organization.",
                    nodes: [
                        ossuCourse("MIT 6.004 — Computation Structures 1", "https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/"),
                        ossuCourse("MIT 6.004 — Computation Structures 2", "https://learning.edx.org/course/course-v1:MITx+6.004.2x+3T2015"),
                        ossuCourse("MIT 6.004 — Computation Structures 3", "https://learning.edx.org/course/course-v1:MITx+6.004.3x_2+1T2017"),
                        videoCourse("Berkeley CS61C — Great Ideas in Computer Architecture", "https://cs61c.org/"),
                        videoCourse("CMU 15-213 — Intro to Computer Systems", "https://www.cs.cmu.edu/~213/")
                    ]
                ),
                ModuleSeed(
                    title: "Advanced Theory",
                    desc: "Automata, computability, and advanced algorithms.",
                    nodes: [
                        ossuCourse("MIT 18.404J — Theory of Computation", "https://ocw.mit.edu/courses/18-404j-theory-of-computation-fall-2020/"),
                        ossuCourse("Computational Geometry — Tsinghua", "https://www.edx.org/learn/geometry/tsinghua-university-ji-suan-ji-he-computational-geometry"),
                        ossuCourse("Algorithmic Game Theory — Tim Roughgarden", "https://timroughgarden.org/f13/f13.html"),
                        videoCourse("MIT 6.045J — Automata, Computability, and Complexity", "https://ocw.mit.edu/courses/6-045j-automata-computability-and-complexity-spring-2011/"),
                        videoCourse("Berkeley CS170 — Algorithms", "https://cs170.org/")
                    ]
                ),
                ModuleSeed(
                    title: "Advanced Security",
                    desc: "Web security, secure SDLC, forensics, and governance.",
                    nodes: [
                        ossuCourse("KU Leuven — Web Security Fundamentals", "https://www.edx.org/learn/computer-security/ku-leuven-web-security-fundamentals"),
                        ossuCourse("Security Governance & Compliance", "https://www.coursera.org/learn/security-governance-compliance"),
                        ossuCourse("Digital Forensics Concepts", "https://www.coursera.org/learn/digital-forensics-concepts"),
                        ossuCourse("Linux Foundation — Secure Software Development", "https://www.edx.org/learn/software-development/the-linux-foundation-secure-software-development-requirements-design-and-reuse"),
                        videoCourse("Stanford CS155 — Computer and Network Security", "https://crypto.stanford.edu/cs155/")
                    ]
                ),
                ModuleSeed(
                    title: "Capstone & Final Project",
                    desc: "Consolidate knowledge with a substantial peer-reviewed project (OSSU final project).",
                    nodes: [
                        concept("Choose a substantial project", "Pick something that exercises systems, algorithms, or full-stack skills."),
                        concept("Document and present your work", "Write README, architecture notes, and a demo."),
                        ossuCourse("OSSU Final Project guidelines", "https://github.com/ossu/computer-science/blob/master/FAQ.md#final-project"),
                        concept("Cross-link: Artificial Intelligence domain", "For ML-heavy capstones, use the LLM Scientist / Engineer tracks in the AI domain.")
                    ]
                )
            ]
        )
    ]
}
