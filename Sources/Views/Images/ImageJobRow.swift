import SwiftUI

struct ImageJobRow: View {
    let job: ImageJob

    var body: some View {
        HStack(spacing: Layout.rowSpacing + 2) {
            JobStatusIcon(status: job.status)
            ImageThumbnail(url: job.input)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.input.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ImageJobDetail(job: job)
            }
            Spacer()
            ImageJobActions(job: job)
        }
        .padding(.vertical, 2)
    }
}
