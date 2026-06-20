//
//  RoboticsEngineeringSeed.swift
//  Sympho
//
//  Mathematics curriculum for robotics, engineering, and AI foundations.
//

import Foundation
import SwiftData

enum RoboticsEngineeringSeed {
    private static let seedKey = "roboticsEngineeringSeedVersion"
    private static let seedVersion = 1
    private static let domainTitle = "Robotics & Engineering"

    static func runIfNeeded(in context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: seedKey) < seedVersion else { return }

        do {
            let domain = try ensureDomain(in: context)
            for trackSeed in tracks {
                let track = ensureTrack(trackSeed, in: domain, context: context)
                seedModules(trackSeed.modules, in: track, context: context)
            }

            domain.updatedAt = Date()
            domain.isSynced = false
            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
        } catch {
            print("Could not seed Robotics & Engineering curriculum: \(error.localizedDescription)")
        }
    }

    private static func ensureDomain(in context: ModelContext) throws -> Domain {
        let domains = try context.fetch(FetchDescriptor<Domain>()).filter { !$0.isDeletedLocally }
        if let existing = domains.first(where: { isRoboticsEngineeringDomain($0.title) }) {
            return existing
        }

        throw RoboticsEngineeringSeedError.missingDomain(
            "No Robotics & Engineering domain found. Create your domain first (e.g. \"Robotics and Engeneering\"), then re-run the seed."
        )
    }

    private static func isRoboticsEngineeringDomain(_ title: String) -> Bool {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
        return normalized.contains("robotics")
            && (normalized.contains("engineering") || normalized.contains("engeneering"))
    }

    enum RoboticsEngineeringSeedError: LocalizedError {
        case missingDomain(String)

        var errorDescription: String? {
            switch self {
            case .missingDomain(let message): return message
            }
        }
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

    private static func concept(_ title: String, _ desc: String) -> NodeSeed {
        NodeSeed(title: title, desc: desc)
    }

    private static func course(_ title: String, _ url: String, note: String = "") -> NodeSeed {
        let extra = note.isEmpty ? "" : "\n\(note)"
        return NodeSeed(title: title, desc: "Course\(extra)\n\(url)")
    }

    private static let tracks: [TrackSeed] = [
        TrackSeed(
            title: "Mathematics",
            desc: "Full math pipeline for robotics, engineering, and AI — algebra through control and kinematics.",
            modules: [
                ModuleSeed(
                    title: "College Algebra",
                    desc: "Functions, equations, and algebraic fluency — the gateway to all higher math.",
                    nodes: [
                        concept("Functions and graphs", "Domain, range, composition, inverses, and transformations."),
                        concept("Polynomial and rational expressions", "Factoring, simplifying, and solving rational equations."),
                        concept("Exponents and logarithms", "Rules, equations, and exponential growth/decay models."),
                        concept("Systems of linear equations", "Substitution, elimination, and matrix preview."),
                        course("OpenStax — College Algebra 2e", "https://openstax.org/details/books/college-algebra-2e"),
                        course("Khan Academy — Algebra 2", "https://www.khanacademy.org/math/algebra2"),
                        course("Paul's Online Math Notes — Algebra", "https://tutorial.math.lamar.edu/classes/alg/alg.aspx")
                    ]
                ),
                ModuleSeed(
                    title: "Trigonometry",
                    desc: "Angles, periodic functions, and polar thinking for rotation and waves.",
                    nodes: [
                        concept("Unit circle and trig functions", "sin, cos, tan and their graphs on the unit circle."),
                        concept("Trig identities and inverse functions", "Pythagorean, angle-sum, and solving trig equations."),
                        concept("Polar coordinates", "Converting between polar and Cartesian; robot pose (r, θ)."),
                        concept("Law of sines and cosines", "Non-right triangle geometry in the physical world."),
                        course("OpenStax — Algebra and Trigonometry 2e", "https://openstax.org/details/books/algebra-and-trigonometry-2e"),
                        course("Khan Academy — Trigonometry", "https://www.khanacademy.org/math/trigonometry"),
                        course("Paul's Online Math Notes — Trigonometry", "https://tutorial.math.lamar.edu/classes/calct/calct.aspx")
                    ]
                ),
                ModuleSeed(
                    title: "Precalculus",
                    desc: "Bridge to calculus — functions, limits intuition, and series preview.",
                    nodes: [
                        concept("Advanced functions", "Composite, piecewise, and inverse function fluency."),
                        concept("Sequences and series (intro)", "Arithmetic/geometric sequences; Taylor preview."),
                        concept("Conic sections", "Parabolas, ellipses, hyperbolas — geometry in motion."),
                        concept("Limits (intuitive)", "Approaching values; continuity before formal Calc I."),
                        course("OpenStax — Precalculus 2e", "https://openstax.org/details/books/precalculus-2e"),
                        course("Khan Academy — Precalculus", "https://www.khanacademy.org/math/precalculus"),
                        course("MIT OCW — Highlights of Calculus (preview)", "https://ocw.mit.edu/courses/18-01sc-single-variable-calculus-fall-2010/")
                    ]
                ),
                ModuleSeed(
                    title: "Calculus I",
                    desc: "Limits, derivatives, and integrals in one variable.",
                    nodes: [
                        concept("Limits and continuity", "Formal limits, continuity, and intermediate value theorem."),
                        concept("Derivatives", "Rules, chain rule, implicit differentiation, related rates."),
                        concept("Applications of derivatives", "Optimization, curve sketching, linear approximation."),
                        concept("Integrals and the FTC", "Antiderivatives, definite integrals, fundamental theorem."),
                        course("OpenStax — Calculus Volume 1", "https://openstax.org/details/books/calculus-volume-1"),
                        course("Khan Academy — Calculus 1", "https://www.khanacademy.org/math/calculus-1"),
                        course("MIT OCW — 18.01 Single Variable Calculus", "https://ocw.mit.edu/courses/18-01sc-single-variable-calculus-fall-2010/"),
                        course("3Blue1Brown — Essence of Calculus", "https://www.youtube.com/playlist?list=PLZHQObOWTQDMsr9K-rj53DwVRMYO3t5Yp")
                    ]
                ),
                ModuleSeed(
                    title: "Calculus II",
                    desc: "Advanced integration, series, and parametric/polar calculus.",
                    nodes: [
                        concept("Integration techniques", "Substitution, parts, partial fractions, trig integrals."),
                        concept("Improper integrals", "Infinite limits and convergence."),
                        concept("Sequences and series", "Convergence tests, Taylor and Maclaurin series."),
                        concept("Parametric and polar calculus", "Derivatives and integrals on curved paths."),
                        course("OpenStax — Calculus Volume 2", "https://openstax.org/details/books/calculus-volume-2"),
                        course("Khan Academy — Calculus 2", "https://www.khanacademy.org/math/calculus-2"),
                        course("Paul's Online Math Notes — Calculus II", "https://tutorial.math.lamar.edu/classes/calcii/calcii.aspx")
                    ]
                ),
                ModuleSeed(
                    title: "Calculus III (Multivariable)",
                    desc: "Partial derivatives, multiple integrals, and vector calculus.",
                    nodes: [
                        concept("Partial derivatives and gradients", "Multi-input rates of change; gradient vectors."),
                        concept("Multiple integrals", "Double and triple integrals; volumes and mass."),
                        concept("Vector fields", "Line integrals, curl, divergence, Green's and Stokes' theorems."),
                        concept("Applications to physics and ML", "Work, flux, and intuition for loss surfaces."),
                        course("OpenStax — Calculus Volume 3", "https://openstax.org/details/books/calculus-volume-3"),
                        course("Khan Academy — Multivariable Calculus", "https://www.khanacademy.org/math/multivariable-calculus"),
                        course("MIT OCW — 18.02 Multivariable Calculus", "https://ocw.mit.edu/courses/18-02sc-multivariable-calculus-fall-2010/"),
                        course("3Blue1Brown — Essence of Linear Algebra (companion)", "https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab")
                    ]
                ),
                ModuleSeed(
                    title: "Differential Equations",
                    desc: "Modeling change — ODEs, Laplace transforms, and dynamical systems.",
                    nodes: [
                        concept("First-order ODEs", "Separable, linear, and modeling with differential equations."),
                        concept("Second-order ODEs", "Homogeneous and nonhomogeneous; mass-spring-damper systems."),
                        concept("Laplace transforms", "Solving ODEs and transfer-function thinking for control."),
                        concept("Systems of ODEs", "Matrix form ẋ = Ax + Bu; state-space preview."),
                        concept("Numerical ODE methods", "Euler, Runge-Kutta; simulation foundations."),
                        course("OpenStax — Elementary Differential Equations", "https://openstax.org/details/books/elementary-differential-equations"),
                        course("MIT OCW — 18.03 Differential Equations", "https://ocw.mit.edu/courses/18-03sc-differential-equations-fall-2011/"),
                        course("Paul's Online Math Notes — Differential Equations", "https://tutorial.math.lamar.edu/classes/de/de.aspx")
                    ]
                ),
                ModuleSeed(
                    title: "Linear Algebra",
                    desc: "Vectors, matrices, and linear transformations — core language of robotics and AI.",
                    nodes: [
                        concept("Vectors and matrix operations", "Addition, multiplication, transpose, inverse."),
                        concept("Linear systems and elimination", "Gaussian elimination, rank, consistency."),
                        concept("Vector spaces and subspaces", "Basis, dimension, span, and linear independence."),
                        concept("Determinants and eigenvalues", "Characteristic polynomials, diagonalization, stability."),
                        concept("Orthogonality and least squares", "Projections, QR, and regression geometry."),
                        concept("Linear transformations", "Rotation matrices, Jacobians, change of basis."),
                        course("MIT OCW — 18.06 Linear Algebra (Strang)", "https://ocw.mit.edu/courses/18-06sc-linear-algebra-fall-2011/"),
                        course("3Blue1Brown — Essence of Linear Algebra", "https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab"),
                        course("OpenStax — Linear Algebra", "https://openstax.org/details/books/linear-algebra"),
                        course("Khan Academy — Linear Algebra", "https://www.khanacademy.org/math/linear-algebra")
                    ]
                ),
                ModuleSeed(
                    title: "Probability & Statistics",
                    desc: "Uncertainty, noise models, estimation, and experimental reasoning.",
                    nodes: [
                        concept("Probability axioms and conditional probability", "Bayes' rule; foundation for sensor fusion."),
                        concept("Random variables and distributions", "Normal, binomial, Poisson; sensor noise models."),
                        concept("Expectation, variance, and CLT", "Why Gaussian noise appears everywhere."),
                        concept("Estimation and hypothesis testing", "MLE, confidence intervals, A/B testing."),
                        concept("Regression and Bayesian inference", "Calibration, Kalman/particle filter preview."),
                        course("OpenStax — Introductory Statistics 2e", "https://openstax.org/details/books/introductory-statistics-2e"),
                        course("MIT OCW — 18.05 Introduction to Probability and Statistics", "https://ocw.mit.edu/courses/18-05-introduction-to-probability-and-statistics-spring-2014/"),
                        course("Khan Academy — Statistics and Probability", "https://www.khanacademy.org/math/statistics-probability"),
                        course("Seeing Theory", "https://seeing-theory.brown.edu/")
                    ]
                ),
                ModuleSeed(
                    title: "Discrete Mathematics",
                    desc: "Logic, sets, combinatorics, and graphs for CS, planning, and rigorous reasoning.",
                    nodes: [
                        concept("Logic and proof techniques", "Direct, contrapositive, contradiction, induction."),
                        concept("Sets, relations, and functions", "Cardinality, equivalence, partial orders."),
                        concept("Combinatorics and counting", "Permutations, combinations, pigeonhole principle."),
                        concept("Graph theory", "Paths, trees, shortest paths — motion planning graphs."),
                        concept("Recurrence relations", "Algorithm analysis and discrete dynamics."),
                        course("MIT OCW — 6.042J Mathematics for Computer Science", "https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-fall-2010/"),
                        course("Book of Proof — Richard Hammack", "https://bookofproof.org/"),
                        course("MIT OCW — 6.006 Introduction to Algorithms (companion)", "https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/")
                    ]
                ),
                ModuleSeed(
                    title: "Numerical Methods",
                    desc: "Computing solutions when closed-form math fails.",
                    nodes: [
                        concept("Root finding and interpolation", "Newton-Raphson, bisection, splines."),
                        concept("Numerical differentiation and integration", "Finite differences, quadrature rules."),
                        concept("Solving linear systems numerically", "Conditioning, LU, iterative methods."),
                        concept("ODE solvers in practice", "Stability, step size, physics simulation."),
                        course("MIT OCW — 18.330 Introduction to Numerical Analysis", "https://ocw.mit.edu/courses/18-330-introduction-to-numerical-analysis-spring-2012/"),
                        course("Cleve Moler — Numerical Computing with MATLAB", "https://www.mathworks.com/moler/chapters.html")
                    ]
                ),
                ModuleSeed(
                    title: "Optimization",
                    desc: "Finding best solutions — unconstrained, constrained, and convex methods.",
                    nodes: [
                        concept("Unconstrained optimization", "Critical points, gradient descent, convexity."),
                        concept("Constrained optimization", "Lagrange multipliers, KKT conditions."),
                        concept("Linear and quadratic programming", "Simplex preview; MPC foundations."),
                        concept("Gradient methods in ML and robotics", "Training networks, inverse kinematics tuning."),
                        course("Stanford EE364A — Convex Optimization", "https://web.stanford.edu/~boyd/cvxbook/"),
                        course("MIT OCW — 6.255J Optimization Methods", "https://ocw.mit.edu/courses/6-255j-optimization-methods-fall-2009/")
                    ]
                ),
                ModuleSeed(
                    title: "Signals, Systems & Fourier",
                    desc: "Frequency domain thinking for sensors, filters, and control.",
                    nodes: [
                        concept("Continuous and discrete signals", "LTI systems, impulse response, convolution."),
                        concept("Fourier series and transform", "Decomposing signals into frequencies."),
                        concept("Sampling and Nyquist theorem", "Digital sensors, aliasing, and reconstruction."),
                        concept("Z-transform (discrete)", "Digital filters and discrete control preview."),
                        course("MIT OCW — 6.003 Signals and Systems", "https://ocw.mit.edu/courses/6-003-signals-and-systems-fall-2011/"),
                        course("MIT OCW — 6.011 Signals, Systems and Inference", "https://ocw.mit.edu/courses/6-011-signals-systems-and-inference-spring-2018/")
                    ]
                ),
                ModuleSeed(
                    title: "Control Theory Mathematics",
                    desc: "Stability, feedback, and state-space control for robots and dynamic systems.",
                    nodes: [
                        concept("Transfer functions and block diagrams", "Classical control representation."),
                        concept("State-space models", "ẋ = Ax + Bu, y = Cx + Du; modern control form."),
                        concept("Stability and poles", "Eigenvalues, BIBO stability, Routh-Hurwitz intuition."),
                        concept("PID control (mathematical view)", "Proportional-integral-derivative tuning."),
                        concept("Controllability and observability", "Can you steer and sense the system?"),
                        concept("LQR and MPC (intro)", "Optimal and model-predictive control preview."),
                        course("MIT OCW — 6.302 Feedback Systems", "https://ocw.mit.edu/courses/6-302-feedback-systems-spring-2007/"),
                        course("Brian Douglas — Control Systems (YouTube)", "https://www.youtube.com/playlist?list=PLUMWjy5gyHK1NC52DXXrriwihVwrKfuEd")
                    ]
                ),
                ModuleSeed(
                    title: "Geometry & Kinematics",
                    desc: "Robotics-specific math — poses, rotations, and manipulator kinematics.",
                    nodes: [
                        concept("Rigid body transforms in 2D and 3D", "Translation + rotation as pose."),
                        concept("Rotation matrices", "SO(2), SO(3), composition, and orthogonality."),
                        concept("Euler angles and gimbal lock", "Why quaternions are preferred in practice."),
                        concept("Quaternions", "Smooth interpolation (slerp); ROS and simulators."),
                        concept("Homogeneous coordinates and SE(3)", "4×4 transforms; standard robotics convention."),
                        concept("Forward and inverse kinematics", "Joint space ↔ end-effector pose."),
                        concept("Jacobian and velocity kinematics", "Relating joint rates to end-effector velocity."),
                        course("Modern Robotics — Lynch & Park (book + Coursera)", "https://modernrobotics.northwestern.edu/"),
                        course("Coursera — Modern Robotics Specialization", "https://www.coursera.org/specializations/modernrobotics"),
                        course("ETH Robot Dynamics lecture notes", "https://rsl.ethz.ch/education-students/lecture-notes.html")
                    ]
                ),
                ModuleSeed(
                    title: "Advanced & Optional Math",
                    desc: "Electives for deeper robotics, engineering, and AI research paths.",
                    nodes: [
                        concept("Partial differential equations", "Heat, wave, and fluid equations in simulation."),
                        concept("Complex analysis", "Useful in advanced ECE and some control theory."),
                        concept("Information theory", "Entropy, compression, and communications bounds."),
                        concept("Stochastic processes", "Random walks, Markov chains, advanced filtering."),
                        concept("Differential geometry and manifolds", "Advanced SLAM and configuration-space geometry."),
                        concept("Tensor calculus", "Continuum mechanics and deep learning research."),
                        course("MIT OCW — 18.100 Real Analysis", "https://ocw.mit.edu/courses/18-100a-introduction-to-analysis-fall-2012/"),
                        course("MIT OCW — 18.650 Statistics for Applications", "https://ocw.mit.edu/courses/18-650-statistics-for-applications-fall-2016/"),
                        concept("Cross-link: Computer Science → Math for CS", "Discrete math depth lives in the CS Core CS track."),
                        concept("Cross-link: Artificial Intelligence → LLM Fundamentals", "Applied ML math depth lives in the AI domain.")
                    ]
                )
            ]
        )
    ]
}
