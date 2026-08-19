import SwiftUI

// هذا هيكل مؤقت لتمثيل التطبيقات المضافة، سيتم ربطه لاحقاً بدوال FilesView
struct HomeAppItem: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let size: String
}

struct HomeView: View {
    // قائمة تجريبية للملفات
    @State private var recentFiles: [HomeAppItem] = [
        HomeAppItem(name: "WhatsApp_Watusi.ipa", version: "23.15.0", size: "115 MB"),
        HomeAppItem(name: "Spotify_Deluxe.ipa", version: "8.8.22", size: "89 MB")
    ]
    
    // الألوان المخصصة للواجهة
    let bannerTurquoise = Color(red: 0.25, green: 0.75, blue: 0.68) // #3fbfae
    let bannerGold = Color(red: 0.91, green: 0.72, blue: 0.36)      // #e8b85c

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. البنر العلوي
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [bannerTurquoise, bannerGold]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 160)
                            .shadow(color: bannerTurquoise.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("مرحباً بك في KINDA")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("الواجهة الرئيسية لإدارة وتوقيع تطبيقاتك.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(20)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // 2. عنوان القسم والأزرار
                    HStack {
                        Text("التطبيقات الجاهزة للتوقيع")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 3. قائمة التطبيقات
                    LazyVStack(spacing: 12) {
                        ForEach(recentFiles) { file in
                            HStack(spacing: 15) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(bannerTurquoise.opacity(0.1))
                                        .frame(width: 55, height: 55)
                                    
                                    Image(systemName: "app.dashed")
                                        .font(.title2)
                                        .foregroundColor(bannerTurquoise)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        Text("الإصدار: \(file.version)")
                                        Text("•")
                                        Text(file.size)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                Button(action: {
                                    // سيتم ربط هذا الزر لاحقاً بـ SignView
                                }) {
                                    Text("توقيع")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(bannerTurquoise)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("الرئيسية")
        }
    }
}
