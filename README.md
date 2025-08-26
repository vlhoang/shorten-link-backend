## Shorten link backend
Project này là một ứng dụng backend có nhiệm vụ tạo link rút gọn từ một link cho trước.  
Techstack sử dụng: APIgateway, lambda, DynamoDB.  
Tổ chức project sử dụng Serverless Application Model - SAM.  
Cấu trúc API:  
* `/api/generate-short-url` có nhiệm vụ nhận vào một URL và trả ra ID rút gọn của URL đó.
* `/link/<id>` với id là mã rút gọn của link gốc, có nhiệm vụ tìm kiếm ID trong DynamoDB Table, nếu match sẽ trả ra link gốc đồng thời thông báo cho trình duyệt điều hướng người dùng sang link đó.

## Yêu cầu: 
* Máy tính cài sẵn SAM CLI và AWS CLI
* Windows/Mac/Linux:
https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html
* Cài sẵn python 3.13

Có thể kiểm tra bằng các lệnh sau nếu chưa chắc chắn:
* `python --version`  
* `sam --version`  
* `aws --version`

## Các bước triển khai
1. Chuẩn bị access key tại local cho AWS CLI, có thể kiểm tra lại bằng lệnh sau:
* `aws sts get-caller-identity`

2. Build application
* `sam build`

3. Deploy ứng dụng.
`sam deploy --guided`

4. Kiểm tra resource trên console, thử access API bằng postman.
* Url (sample): `https://atyn41clp4.execute-api.ap-southeast-1.amazonaws.com/dev/generate-short-url`
* Body (sample):
```
{
    "url":"https://cafebiz.vn/nvidia-cong-ty-3500-ty-usd-lam-rung-chuyen-nganh-chip-toan-cau-ai-khong-canh-tranh-duoc-chi-con-cach-lam-thue-samsung-intel-that-bai-dau-don-vi-muon-dau-tay-doi-176241114100822677.chn"
}
```
* Truy cập thử link rút gọn (sample):
`https://atyn41clp4.execute-api.ap-southeast-1.amazonaws.com/dev/link/jDdfskaJKJ8f9d`

## Xoá resource bằng cách xoá CloudFormation stack trên console hoặc sd lệnh sau
`sam delete --stack-name url-shorten-app`

## Thông tin thêm: sử dụng SAM để test API ở local.
`sam local start-api`

## Chúc các bạn deploy thành công!
