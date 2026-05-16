enum WorkflowStage: String {
    case draft = "待处理"
    case processed = "已生成"
}

enum InsightIntent: String {
    case todo = "TODO"
    case reminder = "定时"
    case material = "素材"
}

struct InsightCard: Identifiable, Equatable {
    let id: Int
    let intent: InsightIntent
    let title: String
    let detail: String
    let actionTitle: String
    let timeText: String?
}

struct VoiceWorkflow {
    var stage: WorkflowStage = .draft
    var transcript = ""
    var polishedText = ""
    var summary = ""
    var cards: [InsightCard] = []

    var canProcess: Bool {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    // 示例语音
    mutating func loadSampleTranscript() {
        transcript = "明天下午三点提醒我给客户发方案，然后把方案里的报价检查一下。还有今天想到一个点，戒指结束录音的时候最好震一下。"
        polishedText = ""
        summary = ""
        cards = []
        stage = .draft
    }

    // AI 整理
    mutating func generateInsights() {
        guard canProcess else { return }

        polishedText = "明天下午三点提醒我给客户发送方案，并检查方案中的报价。另有一个产品交互想法：戒指结束录音时应触发一次震动反馈。"
        summary = "本次语音包含一个定时提醒、一个待办动作和一个长期产品素材。"
        cards = [
            InsightCard(
                id: 1,
                intent: .reminder,
                title: "给客户发送方案",
                detail: "系统需要在指定时间提醒用户完成发送。",
                actionTitle: "创建提醒",
                timeText: "明天 15:00"
            ),
            InsightCard(
                id: 2,
                intent: .todo,
                title: "检查方案报价",
                detail: "发送前确认报价字段和客户版本一致。",
                actionTitle: "加入待办",
                timeText: nil
            ),
            InsightCard(
                id: 3,
                intent: .material,
                title: "结束录音震动反馈",
                detail: "戒指结束录音后发送震动指令，让用户知道录音已完成。",
                actionTitle: "收藏素材",
                timeText: nil
            )
        ]
        stage = .processed
    }

    // 应用结果
    mutating func applyAIResult(_ result: AIWorkflowResult) {
        polishedText = result.polishedText
        summary = result.summary
        cards = result.cards.enumerated().map { index, card in
            InsightCard(
                id: index + 1,
                intent: card.intent,
                title: card.title,
                detail: card.detail,
                actionTitle: card.intent.actionTitle,
                timeText: card.timeText
            )
        }
        stage = .processed
    }

    // 重置流程
    mutating func reset() {
        self = VoiceWorkflow()
    }
}

struct AIWorkflowResult: Decodable, Equatable {
    let polishedText: String
    let summary: String
    let cards: [AICardResult]
}

struct AICardResult: Decodable, Equatable {
    let intent: InsightIntent
    let title: String
    let detail: String
    let timeText: String?
}

extension InsightIntent: Decodable {
    // 意图解析
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)

        switch value {
        case "TODO", "todo":
            self = .todo
        case "定时", "reminder":
            self = .reminder
        case "素材", "material":
            self = .material
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown intent: \(value)")
            )
        }
    }
}

private extension InsightIntent {
    var actionTitle: String {
        switch self {
        case .todo:
            "加入待办"
        case .reminder:
            "创建提醒"
        case .material:
            "收藏素材"
        }
    }
}
