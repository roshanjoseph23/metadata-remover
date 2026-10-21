import Foundation

/// Typed view of `ffprobe -of json` output (only the fields the app asks for).
struct FFprobeOutput: Decodable, Sendable {
    struct Stream: Decodable, Sendable {
        struct Disposition: Decodable, Sendable { let attached_pic: Int? }
        struct SideData: Decodable, Sendable { let rotation: Double? }
        let codec_type: String?
        let codec_name: String?
        let profile: String?
        let width: Int?
        let height: Int?
        let pix_fmt: String?
        let avg_frame_rate: String?
        let r_frame_rate: String?
        let sample_rate: String?
        let channels: Int?
        let color_transfer: String?
        let extradata_hash: String?
        let duration: String?
        let disposition: Disposition?
        let side_data_list: [SideData]?

        var isAttachedPicture: Bool { disposition?.attached_pic == 1 }
    }
    struct Format: Decodable, Sendable { let duration: String? }

    let streams: [Stream]?
    let format: Format?

    static func decode(_ json: String) -> FFprobeOutput? {
        try? JSONDecoder().decode(FFprobeOutput.self, from: Data(json.utf8))
    }
}
