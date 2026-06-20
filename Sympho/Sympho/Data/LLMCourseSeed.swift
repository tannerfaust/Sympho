//
//  LLMCourseSeed.swift
//  Sympho
//
//  Curriculum sourced from Maxime Labonne's LLM course:
//  https://github.com/mlabonne/llm-course
//

import Foundation
import SwiftData

enum LLMCourseSeed {
    private static let seedKey = "llmCourseSeedVersion"
    private static let seedVersion = 1
    private static let domainTitle = "Artificial Intelligence"
    private static let sourceURL = "https://github.com/mlabonne/llm-course"

    static func runIfNeeded(in context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: seedKey) < seedVersion else { return }

        do {
            let domain = try ensureDomain(in: context)
            for (trackIndex, trackSeed) in tracks.enumerated() {
                let track = ensureTrack(trackSeed, at: trackIndex, in: domain, context: context)
                seedModules(trackSeed.modules, in: track, context: context)
            }

            domain.updatedAt = Date()
            domain.isSynced = false
            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedKey)
        } catch {
            print("Could not seed LLM course: \(error.localizedDescription)")
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
            desc: "Comprehensive LLM curriculum based on Maxime Labonne's open LLM course — fundamentals, scientist, engineer, and hands-on notebooks.",
            colorHex: "#1B3A6B",
            iconName: DomainIcon.brain.rawValue,
            sortIndex: nextIndex
        )
        context.insert(domain)
        return domain
    }

    private static func ensureTrack(_ seed: TrackSeed, at index: Int, in domain: Domain, context: ModelContext) -> Track {
        if let existing = domain.tracks.first(where: { $0.title == seed.title && !$0.isDeletedLocally }) {
            return existing
        }

        let track = Track(title: seed.title, desc: seed.desc, sortIndex: index, domain: domain)
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

    private static func resource(_ title: String, _ url: String, note: String = "") -> NodeSeed {
        let suffix = note.isEmpty ? "" : " — \(note)"
        return NodeSeed(title: title, desc: "Resource (\(sourceURL))\(suffix)\n\(url)")
    }

    private static let tracks: [TrackSeed] = [
        TrackSeed(
            title: "LLM Fundamentals",
            desc: "Optional foundations in mathematics, Python, neural networks, and NLP. Refer here as needed before the scientist and engineer paths.",
            modules: [
                ModuleSeed(
                    title: "Mathematics for Machine Learning",
                    desc: "Core mathematical concepts that power machine learning and deep learning algorithms.",
                    nodes: [
                        NodeSeed(title: "Linear algebra foundations", desc: "Vectors, matrices, determinants, eigenvalues and eigenvectors, vector spaces, and linear transformations."),
                        NodeSeed(title: "Calculus for optimization", desc: "Derivatives, integrals, limits, series, multivariable calculus, and gradients for continuous optimization."),
                        NodeSeed(title: "Probability and statistics", desc: "Distributions, expectation, variance, covariance, hypothesis testing, MLE, and Bayesian inference."),
                        resource("3Blue1Brown — Essence of Linear Algebra", "https://www.youtube.com/watch?v=fNk_zzaMoSs&list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab"),
                        resource("StatQuest — Statistics Fundamentals", "https://www.youtube.com/watch?v=qBigTkBLU6g&list=PLblh5JKOoLUK0FLuzwntyYI10UQFUhsY9"),
                        resource("Seeing Theory", "https://seeing-theory.brown.edu/", note: "Visual probability and statistics"),
                        resource("Immersive Linear Algebra", "https://immersivemath.com/ila/learnmore.html"),
                        resource("Khan Academy — Linear Algebra", "https://www.khanacademy.org/math/linear-algebra"),
                        resource("Khan Academy — Calculus", "https://www.khanacademy.org/math/calculus-1"),
                        resource("Khan Academy — Probability and Statistics", "https://www.khanacademy.org/math/statistics-probability")
                    ]
                ),
                ModuleSeed(
                    title: "Python for Machine Learning",
                    desc: "Python fluency and the data-science stack used throughout LLM work.",
                    nodes: [
                        NodeSeed(title: "Python language basics", desc: "Syntax, data types, error handling, and object-oriented programming patterns."),
                        NodeSeed(title: "NumPy, Pandas, and visualization", desc: "Numerical computing, tabular data manipulation, and plotting with Matplotlib and Seaborn."),
                        NodeSeed(title: "Data preprocessing", desc: "Scaling, normalization, missing values, outliers, categorical encoding, and train/validation/test splits."),
                        NodeSeed(title: "Scikit-learn algorithms", desc: "Regression, trees, forests, k-NN, k-means, and dimensionality reduction with PCA and t-SNE."),
                        resource("Real Python", "https://realpython.com/"),
                        resource("freeCodeCamp — Learn Python", "https://www.youtube.com/watch?v=rfscVS0vtbw"),
                        resource("Python Data Science Handbook", "https://jakevdp.github.io/PythonDataScienceHandbook/"),
                        resource("freeCodeCamp — Machine Learning for Everybody", "https://youtu.be/i_LwzRVP7bg"),
                        resource("Udacity — Intro to Machine Learning", "https://www.udacity.com/course/intro-to-machine-learning--ud120")
                    ]
                ),
                ModuleSeed(
                    title: "Neural Networks",
                    desc: "How neural networks are structured, trained, regularized, and implemented.",
                    nodes: [
                        NodeSeed(title: "Network structure and activations", desc: "Layers, weights, biases, and activation functions including sigmoid, tanh, and ReLU."),
                        NodeSeed(title: "Training and optimization", desc: "Backpropagation, MSE and cross-entropy losses, SGD, RMSprop, and Adam."),
                        NodeSeed(title: "Overfitting and regularization", desc: "Dropout, L1/L2 regularization, early stopping, and data augmentation."),
                        NodeSeed(title: "Build an MLP in PyTorch", desc: "Implement a multilayer perceptron end to end to cement feed-forward network mechanics."),
                        resource("3Blue1Brown — But what is a Neural Network?", "https://www.youtube.com/watch?v=aircAruvnKk"),
                        resource("freeCodeCamp — Deep Learning Crash Course", "https://www.youtube.com/watch?v=VyWAvY2CF9c"),
                        resource("Fast.ai — Practical Deep Learning", "https://course.fast.ai/"),
                        resource("Patrick Loeber — PyTorch Tutorials", "https://www.youtube.com/playlist?list=PLqnslRFeH2UrcDBWF5mfPGpqQDSta6VK4")
                    ]
                ),
                ModuleSeed(
                    title: "Natural Language Processing",
                    desc: "Classical NLP building blocks that contextualize modern LLMs.",
                    nodes: [
                        NodeSeed(title: "Text preprocessing", desc: "Tokenization, stemming, lemmatization, and stop-word removal."),
                        NodeSeed(title: "Feature extraction", desc: "Bag-of-words, TF-IDF, and n-grams for classical text representations."),
                        NodeSeed(title: "Word embeddings", desc: "Word2Vec, GloVe, and FastText for dense semantic word representations."),
                        NodeSeed(title: "RNNs, LSTMs, and GRUs", desc: "Sequence modeling and long-range dependency handling before Transformers dominated NLP."),
                        resource("Lena Voita — Word Embeddings", "https://lena-voita.github.io/nlp_course/word_embeddings.html"),
                        resource("Real Python — NLP with spaCy", "https://realpython.com/natural-language-processing-spacy-python/"),
                        resource("Kaggle — NLP Guide", "https://www.kaggle.com/learn-guide/natural-language-processing"),
                        resource("Jay Alammar — Illustrated Word2Vec", "https://jalammar.github.io/illustrated-word2vec/"),
                        resource("Jake Tae — PyTorch RNN from Scratch", "https://jaketae.github.io/study/pytorch-rnn/"),
                        resource("Colah — Understanding LSTMs", "https://colah.github.io/posts/2015-08-Understanding-LSTMs/")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "The LLM Scientist",
            desc: "Build the best possible LLMs — architecture, pre-training, post-training, alignment, evaluation, quantization, and emerging research trends.",
            modules: [
                ModuleSeed(
                    title: "The LLM Architecture",
                    desc: "How modern decoder-only LLMs tokenize, attend, and generate text.",
                    nodes: [
                        NodeSeed(title: "Architectural overview", desc: "From encoder-decoder Transformers to GPT-style decoder-only models."),
                        NodeSeed(title: "Tokenization", desc: "How text becomes tokens and how tokenizer choices affect quality and performance."),
                        NodeSeed(title: "Attention mechanisms", desc: "Self-attention and variants for long-range context and sequence processing."),
                        NodeSeed(title: "Sampling and decoding", desc: "Greedy search, beam search, temperature sampling, and nucleus sampling tradeoffs."),
                        resource("3Blue1Brown — Transformers", "https://www.youtube.com/watch?v=wjZofJX0v4M"),
                        resource("Brendan Bycroft — LLM Visualization", "https://bbycroft.net/llm"),
                        resource("Andrej Karpathy — nanoGPT", "https://www.youtube.com/watch?v=kCc8FmEb1nY"),
                        resource("Andrej Karpathy — Tokenization", "https://www.youtube.com/watch?v=zduSFxRajkE"),
                        resource("Lilian Weng — Attention? Attention!", "https://lilianweng.github.io/posts/2018-06-24-attention/"),
                        resource("Maxime Labonne — Decoding Strategies", "https://mlabonne.github.io/blog/posts/2023-06-07-Decoding_strategies.html")
                    ]
                ),
                ModuleSeed(
                    title: "Pre-Training Models",
                    desc: "Large-scale data preparation and distributed training for base models.",
                    nodes: [
                        NodeSeed(title: "Data preparation at scale", desc: "Curation, cleaning, deduplication, and tokenization for trillion-token corpora."),
                        NodeSeed(title: "Distributed training strategies", desc: "Data, pipeline, and tensor parallelism across GPU clusters."),
                        NodeSeed(title: "Training optimization", desc: "Learning-rate schedules, gradient clipping, mixed precision, and modern optimizers."),
                        NodeSeed(title: "Monitoring pre-training", desc: "Track loss, gradients, GPU stats, and distributed bottlenecks."),
                        resource("FineWeb dataset article", "https://huggingface.co/spaces/HuggingFaceFW/blogpost-fineweb-v1"),
                        resource("RedPajama v2", "https://www.together.ai/blog/redpajama-data-v2"),
                        resource("Hugging Face nanotron", "https://github.com/huggingface/nanotron"),
                        resource("CMU — Parallel Training", "https://www.andrew.cmu.edu/course/11-667/lectures/W10L2%20Scaling%20Up%20Parallel%20Training.pdf"),
                        resource("Survey — Distributed LLM Training", "https://arxiv.org/abs/2407.20018"),
                        resource("Allen AI OLMo 2", "https://allenai.org/olmo"),
                        resource("LLM360", "https://www.llm360.ai/")
                    ]
                ),
                ModuleSeed(
                    title: "Post-Training Datasets",
                    desc: "Curate instruction, preference, and conversational data for alignment stages.",
                    nodes: [
                        NodeSeed(title: "Storage and chat templates", desc: "ShareGPT, OpenAI/HF formats, and templates like ChatML and Alpaca."),
                        NodeSeed(title: "Synthetic data generation", desc: "Use frontier models to create diverse instruction-response pairs at scale."),
                        NodeSeed(title: "Data enhancement techniques", desc: "Rejection sampling, CoT, personas, Auto-Evol, and branch-solve-merge."),
                        NodeSeed(title: "Quality filtering", desc: "Dedup, decontamination, reward models, and judge-LLM quality control."),
                        resource("Argilla Synthetic Data Generator", "https://huggingface.co/spaces/argilla/synthetic-data-generator"),
                        resource("LLM Datasets repo", "https://github.com/mlabonne/llm-datasets"),
                        resource("NVIDIA NeMo-Curator", "https://github.com/NVIDIA/NeMo-Curator"),
                        resource("Distilabel", "https://distilabel.argilla.io/dev/sections/pipeline_samples/"),
                        resource("Semhash", "https://github.com/MinishLab/semhash"),
                        resource("Hugging Face Chat Templates", "https://huggingface.co/docs/transformers/main/en/chat_templating")
                    ]
                ),
                ModuleSeed(
                    title: "Supervised Fine-Tuning",
                    desc: "Turn base models into helpful assistants with efficient fine-tuning.",
                    nodes: [
                        NodeSeed(title: "Full vs parameter-efficient fine-tuning", desc: "LoRA, QLoRA, and when to freeze base weights."),
                        NodeSeed(title: "Training hyperparameters", desc: "Learning rate, batch size, gradient accumulation, epochs, and LoRA rank/alpha."),
                        NodeSeed(title: "Distributed SFT", desc: "DeepSpeed, FSDP, ZeRO stages, and gradient checkpointing."),
                        NodeSeed(title: "SFT monitoring", desc: "Watch loss curves, LR schedules, gradient norms, and instability signals."),
                        resource("Fine-tune Llama 3.1 with Unsloth", "https://huggingface.co/blog/mlabonne/sft-llama3"),
                        resource("Axolotl documentation", "https://axolotl-ai-cloud.github.io/axolotl/"),
                        resource("Hamel Husain — Mastering LLMs", "https://parlance-labs.com/education/"),
                        resource("Sebastian Raschka — LoRA insights", "https://lightning.ai/pages/community/lora-insights/")
                    ]
                ),
                ModuleSeed(
                    title: "Preference Alignment",
                    desc: "Align model outputs with human preferences using modern RLHF alternatives.",
                    nodes: [
                        NodeSeed(title: "Rejection sampling", desc: "Generate multiple answers per prompt and infer chosen/rejected pairs."),
                        NodeSeed(title: "Direct Preference Optimization (DPO)", desc: "Efficient alignment without explicit reward modeling."),
                        NodeSeed(title: "Reward models", desc: "Train judges with human feedback using TRL, verl, or OpenRLHF."),
                        NodeSeed(title: "RL alignment (GRPO and PPO)", desc: "Policy optimization for reasoning models and advanced alignment."),
                        resource("Hugging Face — Illustrating RLHF", "https://huggingface.co/blog/rlhf"),
                        resource("Sebastian Raschka — RLHF and alternatives", "https://magazine.sebastianraschka.com/p/llm-training-rlhf-and-its-alternatives"),
                        resource("Hugging Face — Preference Tuning", "https://huggingface.co/blog/pref-tuning"),
                        resource("Fine-tune Mistral-7b with DPO", "https://mlabonne.github.io/blog/posts/Fine_tune_Mistral_7b_with_DPO.html"),
                        resource("Fine-tune with GRPO", "https://huggingface.co/learn/llm-course/en/chapter12/5"),
                        resource("DPO Wandb logs", "https://wandb.ai/alexander-vishnevskiy/dpo/reports/TRL-Original-DPO--Vmlldzo1NjI4MTc4")
                    ]
                ),
                ModuleSeed(
                    title: "Evaluation",
                    desc: "Measure model quality with benchmarks, humans, and model-based judges.",
                    nodes: [
                        NodeSeed(title: "Automated benchmarks", desc: "Task-specific datasets like MMLU and contamination risks."),
                        NodeSeed(title: "Human evaluation", desc: "Vibe checks, rubric-based annotation, and arena-style voting."),
                        NodeSeed(title: "Model-based evaluation", desc: "Judge and reward models with bias and consistency caveats."),
                        NodeSeed(title: "Closing the feedback loop", desc: "Turn evaluation signals into better data mixtures and training choices."),
                        resource("Hugging Face evaluation guidebook", "https://huggingface.co/spaces/OpenEvals/evaluation-guidebook"),
                        resource("Open LLM Leaderboard", "https://huggingface.co/spaces/open-llm-leaderboard/open_llm_leaderboard"),
                        resource("EleutherAI lm-evaluation-harness", "https://github.com/EleutherAI/lm-evaluation-harness"),
                        resource("Hugging Face lighteval", "https://github.com/huggingface/lighteval"),
                        resource("Chatbot Arena", "https://lmarena.ai/")
                    ]
                ),
                ModuleSeed(
                    title: "Quantization",
                    desc: "Compress models for cheaper inference on consumer and server hardware.",
                    nodes: [
                        NodeSeed(title: "Quantization fundamentals", desc: "FP32, FP16, INT8, absmax, and zero-point techniques."),
                        NodeSeed(title: "GGUF and llama.cpp", desc: "Run LLMs locally on CPUs and consumer GPUs with single-file bundles."),
                        NodeSeed(title: "GPTQ, EXL2, and AWQ", desc: "Layer-wise calibration for ultra-low bitwidth deployment."),
                        NodeSeed(title: "SmoothQuant and ZeroQuant", desc: "Outlier mitigation and compiler optimizations for quantization-friendly inference."),
                        resource("Introduction to quantization", "https://mlabonne.github.io/blog/posts/Introduction_to_Weight_Quantization.html"),
                        resource("Quantize with llama.cpp", "https://mlabonne.github.io/blog/posts/Quantize_Llama_2_models_using_ggml.html"),
                        resource("4-bit quantization with GPTQ", "https://mlabonne.github.io/blog/posts/4_bit_Quantization_with_GPTQ.html"),
                        resource("Understanding AWQ", "https://medium.com/friendliai/understanding-activation-aware-weight-quantization-awq-boosting-inference-serving-efficiency-in-10bb0faf63a8"),
                        resource("SmoothQuant Llama demo", "https://github.com/mit-han-lab/smoothquant/blob/main/examples/smoothquant_llama_demo.ipynb"),
                        resource("DeepSpeed Model Compression", "https://www.deepspeed.ai/tutorials/model-compression/")
                    ]
                ),
                ModuleSeed(
                    title: "New Trends",
                    desc: "Merging, multimodality, interpretability, and test-time compute scaling.",
                    nodes: [
                        NodeSeed(title: "Model merging", desc: "Combine checkpoints with SLERP, DARE, TIES, and mergekit."),
                        NodeSeed(title: "Multimodal models", desc: "Unified embeddings across text, image, and audio modalities."),
                        NodeSeed(title: "Interpretability", desc: "Sparse autoencoders, mechanistic insights, and abliteration."),
                        NodeSeed(title: "Test-time compute scaling", desc: "Reasoning improvements via extra inference budget, MCTS, and PRMs."),
                        resource("Merge LLMs with mergekit", "https://mlabonne.github.io/blog/posts/2024-01-08_Merge_LLMs_with_mergekit.html"),
                        resource("Smol Vision", "https://github.com/merveenoyan/smol-vision"),
                        resource("Chip Huyen — Multimodal Models", "https://huyenchip.com/2023/10/10/multimodal.html"),
                        resource("Uncensor any LLM with abliteration", "https://huggingface.co/blog/mlabonne/abliteration"),
                        resource("Adam Karvonen — SAE intuitions", "https://adamkarvonen.github.io/machine_learning/2024/06/11/sae-intuitions.html"),
                        resource("Scaling test-time compute", "https://huggingface.co/spaces/HuggingFaceH4/blogpost-scaling-test-time-compute")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "The LLM Engineer",
            desc: "Build and deploy production LLM applications — RAG, agents, optimization, deployment, and security.",
            modules: [
                ModuleSeed(
                    title: "Running LLMs",
                    desc: "Consume and run models via APIs or locally with strong prompting practices.",
                    nodes: [
                        NodeSeed(title: "LLM APIs", desc: "Private providers (OpenAI, Google, Anthropic) and open routers (OpenRouter, HF, Together)."),
                        NodeSeed(title: "Open-source local LLMs", desc: "Discover models on Hugging Face and run with LM Studio, llama.cpp, or Ollama."),
                        NodeSeed(title: "Prompt engineering", desc: "Zero-shot, few-shot, chain-of-thought, and ReAct patterns."),
                        NodeSeed(title: "Structured outputs", desc: "Constrain generations with Outlines, JSON schemas, and native API modes."),
                        resource("Run LLMs locally with LM Studio", "https://www.kdnuggets.com/run-an-llm-locally-with-lm-studio"),
                        resource("Prompt Engineering Guide", "https://www.promptingguide.ai/"),
                        resource("Outlines quickstart", "https://dottxt-ai.github.io/outlines/latest/quickstart/"),
                        resource("LMQL overview", "https://lmql.ai/docs/language/overview.html")
                    ]
                ),
                ModuleSeed(
                    title: "Building a Vector Storage",
                    desc: "Ingest, chunk, embed, and store documents for retrieval pipelines.",
                    nodes: [
                        NodeSeed(title: "Ingesting documents", desc: "Load PDFs, JSON, HTML, Markdown, and remote sources with document loaders."),
                        NodeSeed(title: "Splitting documents", desc: "Semantic chunking by headers, recursion, and metadata-aware splits."),
                        NodeSeed(title: "Embedding models", desc: "Pick task-specific embedders for search and RAG quality."),
                        NodeSeed(title: "Vector databases", desc: "Chroma, Pinecone, Milvus, FAISS, Annoy, and similarity retrieval."),
                        resource("LangChain text splitters", "https://python.langchain.com/docs/how_to/#text-splitters"),
                        resource("Sentence Transformers", "https://www.sbert.net/"),
                        resource("MTEB Leaderboard", "https://huggingface.co/spaces/mteb/leaderboard"),
                        resource("Top vector databases comparison", "https://www.datacamp.com/blog/the-top-5-vector-databases")
                    ]
                ),
                ModuleSeed(
                    title: "Retrieval Augmented Generation",
                    desc: "Augment LLM answers with retrieved context instead of fine-tuning.",
                    nodes: [
                        NodeSeed(title: "RAG orchestrators", desc: "LangChain, LlamaIndex, and MCP as context standards."),
                        NodeSeed(title: "Retrievers", desc: "Query rewriting, HyDE, CoRAG, and hybrid retrieval strategies."),
                        NodeSeed(title: "Memory for chat apps", desc: "Context windows, summarization, and vector-backed memory."),
                        NodeSeed(title: "RAG evaluation", desc: "Measure retrieval and generation quality with Ragas and DeepEval."),
                        resource("LlamaIndex core concepts", "https://docs.llamaindex.ai/en/stable/getting_started/concepts.html"),
                        resource("Model Context Protocol", "https://modelcontextprotocol.io/introduction"),
                        resource("Pinecone — Retrieval Augmentation", "https://www.pinecone.io/learn/series/langchain/langchain-retrieval-augmentation/"),
                        resource("LangChain RAG tutorial", "https://python.langchain.com/docs/tutorials/rag/"),
                        resource("LangChain memory types", "https://python.langchain.com/docs/how_to/chatbots_memory/"),
                        resource("Ragas metrics", "https://docs.ragas.io/en/stable/concepts/metrics/index.html")
                    ]
                ),
                ModuleSeed(
                    title: "Advanced RAG",
                    desc: "Complex pipelines with SQL/graph retrieval, tools, reranking, and programmatic optimization.",
                    nodes: [
                        NodeSeed(title: "Query construction", desc: "Translate natural language into SQL, Cypher, and structured queries."),
                        NodeSeed(title: "Tool-using agents", desc: "Let models pick calculators, search, code execution, and APIs."),
                        NodeSeed(title: "Post-processing", desc: "Reranking, RAG-fusion, and classification before generation."),
                        NodeSeed(title: "Programmatic LLM optimization", desc: "DSPy for automated prompt and weight optimization."),
                        resource("LangChain query construction", "https://blog.langchain.dev/query-construction/"),
                        resource("LangChain SQL QA", "https://python.langchain.com/docs/tutorials/sql_qa/"),
                        resource("Pinecone — LLM agents", "https://www.pinecone.io/learn/series/langchain/langchain-agents/"),
                        resource("Lilian Weng — LLM Powered Agents", "https://lilianweng.github.io/posts/2023-06-23-agent/"),
                        resource("LangChain — OpenAI RAG strategies", "https://blog.langchain.dev/applying-openai-rag/"),
                        resource("DSPy in 8 steps", "https://dspy-docs.vercel.app/docs/building-blocks/solving_your_task")
                    ]
                ),
                ModuleSeed(
                    title: "Agents",
                    desc: "Autonomous systems that reason, act, and observe through tools and protocols.",
                    nodes: [
                        NodeSeed(title: "Agent loop fundamentals", desc: "Thought, action, and observation cycles for task completion."),
                        NodeSeed(title: "Agent protocols", desc: "MCP for tool/data access and A2A for agent interoperability."),
                        NodeSeed(title: "Vendor agent frameworks", desc: "OpenAI Agents SDK, Google ADK, and Claude Agent SDK."),
                        NodeSeed(title: "Open agent frameworks", desc: "LangGraph, LlamaIndex agents, CrewAI, and AutoGen."),
                        resource("Hugging Face Agents Course", "https://huggingface.co/learn/agents-course/unit0/introduction"),
                        resource("LangGraph concepts", "https://langchain-ai.github.io/langgraph/concepts/why-langgraph/"),
                        resource("LlamaIndex agents", "https://docs.llamaindex.ai/en/stable/use_cases/agents/")
                    ]
                ),
                ModuleSeed(
                    title: "Inference Optimization",
                    desc: "Maximize throughput and reduce serving cost beyond quantization.",
                    nodes: [
                        NodeSeed(title: "Flash Attention", desc: "Linear-complexity attention kernels for faster training and inference."),
                        NodeSeed(title: "KV cache, MQA, and GQA", desc: "Memory-efficient attention variants for long contexts."),
                        NodeSeed(title: "Speculative decoding", desc: "Draft with small models, verify with large ones — including EAGLE-3."),
                        resource("Hugging Face GPU inference", "https://huggingface.co/docs/transformers/main/en/perf_infer_gpu_one"),
                        resource("Databricks LLM inference", "https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices"),
                        resource("HF — Optimizing LLMs for speed and memory", "https://huggingface.co/docs/transformers/main/en/llm_tutorial_optimization"),
                        resource("HF assisted generation", "https://huggingface.co/blog/assisted-generation"),
                        resource("EAGLE-3 paper", "https://arxiv.org/abs/2503.01840"),
                        resource("vLLM speculators", "https://github.com/vllm-project/speculators")
                    ]
                ),
                ModuleSeed(
                    title: "Deploying LLMs",
                    desc: "From local demos to cloud-scale serving and edge deployment.",
                    nodes: [
                        NodeSeed(title: "Local deployment", desc: "Privacy-focused apps with LM Studio, Ollama, oobabooga, and kobold.cpp."),
                        NodeSeed(title: "Demo deployment", desc: "Prototype quickly with Gradio, Streamlit, and Hugging Face Spaces."),
                        NodeSeed(title: "Server deployment", desc: "Cloud and on-prem serving with TGI, vLLM, and SkyPilot."),
                        NodeSeed(title: "Edge deployment", desc: "MLC LLM and mnn-llm for browsers and mobile devices."),
                        resource("Streamlit LLM app tutorial", "https://docs.streamlit.io/knowledge-base/tutorials/build-conversational-apps"),
                        resource("HF SageMaker inference container", "https://huggingface.co/blog/sagemaker-huggingface-llm"),
                        resource("Philipp Schmid blog", "https://www.philschmid.de/"),
                        resource("Hamel Husain — latency comparison", "https://hamel.dev/notes/llm/inference/03_inference.html")
                    ]
                ),
                ModuleSeed(
                    title: "Securing LLMs",
                    desc: "Threat models and defenses unique to LLM applications.",
                    nodes: [
                        NodeSeed(title: "Prompt hacking", desc: "Injection, data leaking, and jailbreak patterns."),
                        NodeSeed(title: "Backdoors and data poisoning", desc: "Training-time attacks and hidden triggers."),
                        NodeSeed(title: "Defensive measures", desc: "Red teaming, garak testing, and production monitoring with Langfuse."),
                        resource("OWASP LLM Top 10", "https://owasp.org/www-project-top-10-for-large-language-model-applications/"),
                        resource("Prompt Injection Primer", "https://github.com/jthack/PIPE"),
                        resource("LLM Security resource list", "https://llmsecurity.net/"),
                        resource("Microsoft red teaming guide", "https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/red-teaming")
                    ]
                )
            ]
        ),
        TrackSeed(
            title: "Hands-On Notebooks & Tools",
            desc: "Practical Colab notebooks and one-click tools from the course repository for experimentation.",
            modules: [
                ModuleSeed(
                    title: "Course Tools",
                    desc: "Utility repos for evaluation, merging, quantization, and rapid prototyping.",
                    nodes: [
                        resource("LLM AutoEval", "https://github.com/mlabonne/llm-autoeval", note: "Evaluate LLMs on RunPod"),
                        NodeSeed(title: "LazyMergekit", desc: "One-click model merging with MergeKit."),
                        NodeSeed(title: "LazyAxolotl", desc: "Cloud fine-tuning with Axolotl in one click."),
                        NodeSeed(title: "AutoQuant", desc: "Quantize to GGUF, GPTQ, EXL2, AWQ, and HQQ in one click."),
                        NodeSeed(title: "Model Family Tree", desc: "Visualize merged model genealogies."),
                        NodeSeed(title: "ZeroSpace", desc: "Spin up a Gradio chat UI on ZeroGPU."),
                        NodeSeed(title: "AutoAbliteration", desc: "Automated abliteration with custom datasets."),
                        NodeSeed(title: "AutoDedup", desc: "Dataset deduplication with the Rensa library.")
                    ]
                ),
                ModuleSeed(
                    title: "Fine-Tuning Notebooks",
                    desc: "Hands-on supervised and preference fine-tuning walkthroughs.",
                    nodes: [
                        resource("Fine-tune Llama 3.1 with Unsloth", "https://mlabonne.github.io/blog/posts/2024-07-29_Finetune_Llama31.html"),
                        resource("Fine-tune Llama 3 with ORPO", "https://mlabonne.github.io/blog/posts/2024-04-19_Fine_tune_Llama_3_with_ORPO.html"),
                        resource("Fine-tune Mistral-7b with DPO", "https://mlabonne.github.io/blog/posts/Fine_tune_Mistral_7b_with_DPO.html"),
                        NodeSeed(title: "Fine-tune Mistral-7b with QLoRA", desc: "Supervised fine-tune in free-tier Colab with TRL."),
                        resource("Fine-tune CodeLlama using Axolotl", "https://mlabonne.github.io/blog/posts/A_Beginners_Guide_to_LLM_Finetuning.html"),
                        resource("Fine-tune Llama 2 with QLoRA", "https://mlabonne.github.io/blog/posts/Fine_Tune_Your_Own_Llama_2_Model_in_a_Colab_Notebook.html")
                    ]
                ),
                ModuleSeed(
                    title: "Quantization Notebooks",
                    desc: "Practical compression and fast inference notebooks.",
                    nodes: [
                        resource("Introduction to Quantization", "https://mlabonne.github.io/blog/posts/Introduction_to_Weight_Quantization.html"),
                        resource("4-bit Quantization using GPTQ", "https://mlabonne.github.io/blog/4bit_quantization/"),
                        resource("Quantization with GGUF and llama.cpp", "https://mlabonne.github.io/blog/posts/Quantize_Llama_2_models_using_ggml.html"),
                        resource("ExLlamaV2 — Fastest Library to Run LLMs", "https://mlabonne.github.io/blog/posts/ExLlamaV2_The_Fastest_Library_to_Run%C2%A0LLMs.html")
                    ]
                ),
                ModuleSeed(
                    title: "Other Practical Notebooks",
                    desc: "Merging, MoEs, abliteration, knowledge graphs, and decoding deep dives.",
                    nodes: [
                        resource("Merge LLMs with MergeKit", "https://mlabonne.github.io/blog/posts/2024-01-08_Merge_LLMs_with_mergekit%20copy.html"),
                        resource("Create MoEs with MergeKit", "https://mlabonne.github.io/blog/posts/2024-03-28_Create_Mixture_of_Experts_with_MergeKit.html"),
                        resource("Uncensor any LLM with abliteration", "https://mlabonne.github.io/blog/posts/2024-06-04_Uncensor_any_LLM_with_abliteration.html"),
                        resource("Improve ChatGPT with Knowledge Graphs", "https://mlabonne.github.io/blog/posts/Article_Improve_ChatGPT_with_Knowledge_Graphs.html"),
                        resource("Decoding Strategies in LLMs", "https://mlabonne.github.io/blog/posts/2022-06-07-Decoding_strategies.html")
                    ]
                )
            ]
        )
    ]
}
