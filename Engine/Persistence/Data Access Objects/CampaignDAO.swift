import Foundation
import SQLite3

public class CampaignDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "campaign", loggerName: CampaignDAO.self)
    }

}
