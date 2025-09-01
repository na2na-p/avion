package main

import (
	"fmt"
	"log"

	authv1 "github.com/na2na-p/avion/proto/avion/auth/v1"
	commonv1 "github.com/na2na-p/avion/proto/avion/common/v1"
	dropv1 "github.com/na2na-p/avion/proto/avion/drop/v1"
	userv1 "github.com/na2na-p/avion/proto/avion/user/v1"
)

func main() {
	// テスト1: 共通パッケージのPaginationRequestを作成
	pagination := &commonv1.PaginationRequest{
		PageSize:  10,
		PageToken: "test-token",
	}
	fmt.Printf("PaginationRequest: PageSize=%d, PageToken=%s\n", pagination.PageSize, pagination.PageToken)

	// テスト2: AuthサービスのListSessionsRequestを作成
	listSessionsReq := &authv1.ListSessionsRequest{
		UserId:     "user123",
		Pagination: pagination,
	}
	fmt.Printf("ListSessionsRequest: UserId=%s\n", listSessionsReq.UserId)

	// テスト3: UserサービスのCreateUserRequestを作成
	createUserReq := &userv1.CreateUserRequest{
		Username:    "testuser",
		Email:       "test@example.com",
		DisplayName: "Test User",
	}
	fmt.Printf("CreateUserRequest: Username=%s, Email=%s\n", createUserReq.Username, createUserReq.Email)

	// テスト4: DropサービスのCreateDropRequestを作成
	createDropReq := &dropv1.CreateDropRequest{
		Content:    "Hello, Avion!",
		Visibility: dropv1.DropVisibility_DROP_VISIBILITY_PUBLIC,
	}
	fmt.Printf("CreateDropRequest: Content=%s, Visibility=%s\n", createDropReq.Content, createDropReq.Visibility)

	// テスト5: エラーコードの確認
	errorCode := commonv1.ErrorCode_ERROR_CODE_NOT_FOUND
	fmt.Printf("ErrorCode: %s\n", errorCode)

	log.Println("✅ すべてのProtocol Buffersメッセージが正常に動作しています！")
}