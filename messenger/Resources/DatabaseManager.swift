//
//  DatabaseManager.swift
//  messenger
//
//  Created by Viet on 10/21/21.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
}

// MARK: - Account Management

extension DatabaseManager {
    
    public func userExists(with email: String,
                           completion: @escaping((Bool) -> Void)){
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value) { (snapshot) in
            guard snapshot.value as? String != nil  else {
                completion(false)
                return
            }
            completion(true)
        }
        
    }
    
    /// Inserts new user to database
    
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void){
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ]) { (error, _) in
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value) { (snapshot) in
                if var usersCollection = snapshot.value as? [[String: String]]{
                    // append user to dictionary
                    let newElement =
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection) { (error, _) in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                } else {
                    // create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection) { (error, _) in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                    
                }
            }
        }
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { (snapshot) in
            guard let value = snapshot.value as? [[String: String]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    /**
     users  =>  [
     [
     "name":
     "safe_emai"l:
     ],
     [
     "name":
     "safe_email":
     ]
     ]
     */
    
}

//MARK: - Sending Messages/ Conversations

extension DatabaseManager {
    
    /**
     "1234" {
     "messages" :  [
     {
     "id" : String
     "type": text, photo, video
     "content": String
     "date": Date()
     "sender_email": String
     "isRead": true/false
     }
     ]
     }
     conversation  =>  [
     [
     "conversation_id": "1234"
     "other_user_email":
     "latest_message": => {
     "date": Date()
     "lates_message": "message"
     "is_read": true/false
     }
     ],
     ]
     */
    
    /// Creates a new conversations with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> Void ){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child(safeEmail)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { (snapshot) in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate;
            let dateString = ChatViewController.dateFormater.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind {
            
            case .text(let messagetext):
                message = messagetext
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "latest_message": [
                    "date": dateString ,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for this user
                // you should append
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode) { [weak self] (error, _) in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
            } else {
                // conversation array does not exist
                // create it
                userNode["conversations"] = [newConversationData]
                ref.setValue(userNode) { [weak self] (error, _) in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self? .finishCreatingConversation(conversationID: conversationID,
                                                      firstMessage: firstMessage,
                                                      completion: completion)
                }
            }
        }
    }
    
    private func finishCreatingConversation(conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void){
        
        
        //        "messages" :  [
        //            {
        //                "id" : String
        //                "type": text, photo, video
        //                "content": String
        //                "date": Date()
        //                "sender_email": String
        //                "isRead": true/false
        //            }
        //        ]
        let messageDate = firstMessage.sentDate;
        let dateString = ChatViewController.dateFormater.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        
        case .text(let messagetext):
            message = messagetext
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentEmail,
            "is_read": false
        ]
        
        let value: [String: Any] = [
            "messages" : [
                collectionMessage
            ]
        ]
        
        database.child(conversationID).setValue(value) { (error, _) in
            guard error ==  nil else {
                completion(false)
                return
            }
            completion(true)
        }
        
    }
    
    /// Fetches and returns all conversations for the user with passed email
    public func getAllConversations(for email: String, completion: @escaping (Result<String, Error>) -> Void){
        
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForCconversation(with id: String, completion: @escaping(Result<String, Error>) -> Void){
        
    }
    
    /// Sends a message with target conversation and message
    public func sendMessages(to conversation: String, message: Message, completion: @escaping(Bool) -> Void){
        
    }
    
    
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        //viet-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
    
}
