```mermaid
erDiagram

        PostScope {
            PUBLIC PUBLIC
HOME HOME
FOLLOWERS_ONLY FOLLOWERS_ONLY
        }
    


        BaseUserType {
            ADMIN ADMIN
MODERATOR MODERATOR
USER USER
BOT BOT
        }
    


        TimelineType {
            HOME_TIMELINE HOME_TIMELINE
LOCAL_TIMELINE LOCAL_TIMELINE
GLOBAL_TIMELINE GLOBAL_TIMELINE
        }
    
  "User" {
    String id "🗝️"
    String userId 
    String email 
    String name "❓"
    String introduction "❓"
    String password 
    DateTime createdAt 
    DateTime deletedAt "❓"
    }
  

  "RolesOnUsers" {
    String id 
    DateTime assiginedAt 
    }
  

  "Role" {
    String id "🗝️"
    String name 
    BaseUserType baseType 
    }
  

  "Terminal" {
    String id "🗝️"
    }
  

  "Medium" {
    String id "🗝️"
    }
  
    "User" o|--|o "Terminal" : "Terminal"
    "User" o|--|o "Medium" : "Medium"
    "User" o{--}o "RolesOnUsers" : "assignedRoles"
    "RolesOnUsers" o|--|| "User" : "User"
    "RolesOnUsers" o|--|| "Role" : "Role"
    "Role" o|--|| "BaseUserType" : "enum:baseType"
    "Role" o{--}o "RolesOnUsers" : "users"
    "Terminal" o{--}o "User" : "users"
    "Medium" o{--}o "User" : "users"
```
