## Shorten link backend
Project này là một ứng dụng backend có nhiệm vụ tạo link rút gọn từ một link cho trước.  
Techstack sử dụng: APIgateway, lambda, DynamoDB.  
Tổ chức project sử dụng Serverless Application Model - SAM.  
Cấu trúc API:  
* `/api/generate-short-url` có nhiệm vụ nhận vào một URL và trả ra ID rút gọn của URL đó.
* `/api/link/<id>` với id là mã rút gọn của link gốc, có nhiệm vụ tìm kiếm ID trong DynamoDB Table, nếu match sẽ trả ra link gốc đồng thời thông báo cho trình duyệt điều hướng người dùng sang link đó.

## Yêu cầu: 
* Máy tính cài sẵn azure function core tools và Azure CLI
* Windows/Mac/Linux:
https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Cisolated-process%2Cnode-v4%2Cpython-v2%2Chttp-trigger%2Ccontainer-apps&pivots=programming-language-python

* Cài sẵn python 3.13

Có thể kiểm tra bằng các lệnh sau nếu chưa chắc chắn:
* `python --version`  
* `az --version`  
* `func --version`

## Các bước triển khai
1. Đăng nhập vào Azure CLI bằng lệnh sau:
* `az login`

2. Tạo resource group trên Azure, đặt tên là `shorten-link-app-rg` (tạo trên portal hoặc CLI)

3. Deploy hạ tầng trên Azure bằng bicep
* `az deployment group create --resource-group shorten-link-app-rg --template-file template.bicep`

Tên các resource đang là random, nếu muốn tự đặt tên, sử dụng file parameter.bicepparam (lưu ý đặt tên unique global), sau đó thêm tham số template vào câu lệnh deploy
`--parameters parameters.bicepparam`

4. Deploy ứng dụng lên azure function, thay tên function app của bạn vào lệnh:
`func azure functionapp publish <function app name> --python`

4. Kiểm tra resource trên console, thử access API bằng postman.
* Url (sample): `https://hvlinhslinkapim.azure-api.net/api/generate-short-url`
* Body (sample):
```
{
    "url":"https://cafebiz.vn/nvidia-cong-ty-3500-ty-usd-lam-rung-chuyen-nganh-chip-toan-cau-ai-khong-canh-tranh-duoc-chi-con-cach-lam-thue-samsung-intel-that-bai-dau-don-vi-muon-dau-tay-doi-176241114100822677.chn"
}
```
* Truy cập thử link rút gọn (sample):
`https://hvlinhslinkapim.azure-api.net/api/link/jDdfskaJKJ8f9d`

## Xoá resource bằng cách xoá resource group shorten-link-app-rg bằng portal hoặc bằng lệnh

## Chúc các bạn deploy thành công!
