import SwiftUI

struct SidebarListItemView: View {
    let activity: ClientActivity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(activity.displayTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.euniText)
                    .lineLimit(1)
                Spacer()
            }
            
            HStack {
                Text(activity.type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(Color.euniSecondary)
                Spacer()
                Text(activity.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(Color.euniSecondary)
            }
            
            if !activity.content.isEmpty {
                Text(activity.content)
                    .font(.subheadline)
                    .foregroundColor(Color.euniSecondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        // Optionally, add a context menu for future actions
    }
}
