//Port from https://github.com/AlvaroFranco/AFSQLManager

import Foundation
#if os(Linux)
import CSQLite
#else
import SQLite3
#endif

class AFSQLManager {
    private static let _sharedManager: AFSQLManager = AFSQLManager()
    
    static func sharedManager() -> AFSQLManager {
        return _sharedManager
    }
    
    private var currentDbInfo: [String:String]? = nil
    public var database: OpaquePointer { return _database! }
    fileprivate var _database: OpaquePointer? = nil
    public struct AFSQLManagerError: Error {}
    
    func createDatabaseWithName(name: String, openImmediately: Bool, withStatusBlock: (Bool, Error?) -> ()) {
        do {
            let data:NSData = NSData(data: Data())
            let comp:String = NSURL(string: name)!.lastPathComponent!
            let comp2:String = NSString(string: comp).deletingPathExtension
            let ext = NSURL(string: name)!.pathExtension!
            let filename:String = Bundle.main.path(forResource: comp2, ofType: ext)!
            try data.write(toFile: filename, options: NSData.WritingOptions.atomic)
            if openImmediately {
                self.openLocalDatabaseWithName(name: name) {success, error in
                    if success {
                        currentDbInfo = ["name": name]
                    }
                    withStatusBlock(success, error)
                }
            } else {
                withStatusBlock(true, nil)
            }
        } catch {
            withStatusBlock(false, AFSQLManagerError())
        }
    }
    
    func openLocalDatabaseWithName(name: String, andStatusBlock: (Bool, Error?) -> ()) {
        let comp:String = NSURL(string: name)!.lastPathComponent!
        let comp2:String = NSString(string: comp).deletingPathExtension
        let ext = NSURL(string: name)!.pathExtension!
        print(Bundle.main.bundlePath)
        if let path:String = Bundle.main.path(forResource: comp2, ofType: ext) {
            if sqlite3_open(path, &_database) != SQLITE_OK {
                print("Failed to open database!");
                andStatusBlock(false, AFSQLManagerError());
            } else {
                print("Database opened properly");
                andStatusBlock(true, nil);
            }
        } else {
            print("Failed to open database! path is nil");
            andStatusBlock(false, AFSQLManagerError());
        }
    }
    
    func closeLocalDatabaseWithName(name: String, andStatusBlock: (Bool, Error?) -> ()) {
        if sqlite3_close(_database) == SQLITE_OK {
            andStatusBlock(true, nil)
        } else {
            
        }
    }
    
    func renameDatabaseWithName(originalName: String, toName: String, andStatusBlock: (Bool, Error?) -> ()) {
        if currentDbInfo != nil && currentDbInfo!["name"] == originalName {
            sqlite3_close(_database)
        }
        
        do {
            let filemanager:FileManager = FileManager.default
            
            let comp_ori:String = NSURL(string: originalName)!.lastPathComponent!
            let comp2_ori:String = NSString(string: comp_ori).deletingPathExtension
            let ext_ori = NSURL(string: originalName)!.pathExtension!
            let path_ori:String = Bundle.main.path(forResource: comp2_ori, ofType: ext_ori)!
            
            let comp_to:String = NSURL(string: toName)!.lastPathComponent!
            let comp2_to:String = NSString(string: comp_to).deletingPathExtension
            let ext_to = NSURL(string: toName)!.pathExtension!
            let path_to:String = Bundle.main.path(forResource: comp2_to, ofType: ext_to)!
            
            try filemanager.moveItem(atPath: path_ori, toPath: path_to)
            
            if currentDbInfo != nil && currentDbInfo!["name"] == originalName {
                self.openLocalDatabaseWithName(name: toName) {_,_ in }
                currentDbInfo = ["name": toName]
                andStatusBlock(true, nil)
            }
        } catch {
            if currentDbInfo != nil && currentDbInfo!["name"] == originalName {
                self.openLocalDatabaseWithName(name: originalName) {_,_ in }
            }
            andStatusBlock(false, error)
        }
    }
    
    func deleteDatabaseWithName(name: String, andStatus: (Bool, Error?) -> ()) {
        if currentDbInfo != nil && currentDbInfo!["name"] == name {
            sqlite3_close(_database)
        }
        
        do {
            let filemanager:FileManager = FileManager.default
            
            let comp:String = NSURL(string: name)!.lastPathComponent!
            let comp2:String = NSString(string: comp).deletingPathExtension
            let ext = NSURL(string: name)!.pathExtension!
            let path:String = Bundle.main.path(forResource: comp2, ofType: ext)!
            
            try filemanager.removeItem(atPath: path)
            
            andStatus(true, nil)
            currentDbInfo = ["name": ""]
        } catch {
            andStatus(false, error)
            self.openLocalDatabaseWithName(name: name) {_,_ in }
        }
    }
    
    func performQuery(query: String, withBlock: ([String]?, Error?, Bool) -> ()) {
        let fixedQuery:String = query.trimmingCharacters(in: CharacterSet.newlines)
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(_database, fixedQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                var row:[String] = []
                for i in 0..<sqlite3_column_count(statement) {
                    if let p = sqlite3_column_text(statement, i) {
                        row.append(String(cString: p))
                    } else {
                        row.append("")
                    }
                }
                
                withBlock(row, nil, false)
            }
            
            sqlite3_finalize(statement)
            withBlock(nil, nil, true)
        }
    }
    
    func test001() {
        print("test001...")
        let dbname:String = "list.db"
        var openSuccess:Bool = true
        AFSQLManager.sharedManager().openLocalDatabaseWithName(name: dbname) {success, error in
            if error != nil {
                openSuccess = false
            }
        }
        print("openSuccess: ", openSuccess)
        if (openSuccess) {
            let query:String = String(format: "SELECT name, items from list where name = \"%@\" ", "和")
            var items:String? = nil
            AFSQLManager.sharedManager().performQuery(query: query) {row, error, finished in
                if error == nil {
                    if !finished {
                        print("row: ", row!)
                        items = row![1]
                    } else {
                        if items != nil {
                            print("items: ", items!)
                            let arrItems: [String] = items!.components(separatedBy: "|")
                            for items2 in arrItems {
                                print("items2: ", items2)
                                let arrItem: [String] = items2.components(separatedBy: ",")
                                print("arrItem: ", arrItem)
                                if arrItem.count >= 3 {
                                    print("strWord: ", arrItem[0])
                                    print("strSound: ", arrItem[1])
                                    print("strRomaji: ", arrItem[2])
                                }
                                print("==========")
                            }
                        }
                        print("performSelectorOnMainThread")
                    }
                } else {
                    print("query error")
                }
            }
            AFSQLManager.sharedManager().closeLocalDatabaseWithName(name: dbname) {_,_ in }
        }
    }
}

