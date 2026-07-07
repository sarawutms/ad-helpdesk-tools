# AD Helpdesk Tool 🛡️

A secure, GUI-based PowerShell utility for IT Helpdesk and System Administrators to manage Active Directory accounts and computers efficiently. 

โปรแกรมสำหรับช่วยเหลือ IT Helpdesk ในการจัดการ Active Directory ผ่านหน้าต่าง GUI ที่ใช้งานง่าย ปลอดภัย และไม่ต้องพิมพ์คำสั่ง PowerShell เอง

## ✨ Key Features (จุดเด่นของโปรแกรม)

* **User-Friendly GUI:** อินเทอร์เฟซแบบหน้าต่าง (Windows Forms) ใช้งานง่าย ค้นหาได้ทั้ง User และ Computer ในช่องเดียว (Unified Search)
* **Security First (เน้นความปลอดภัยเป็นหลัก):**
  * **No Hardcoded Domain:** ดึงค่าโดเมนจากเครื่องที่ใช้งานอัตโนมัติ (`$env:USERDOMAIN`) ป้องกันข้อมูลโครงสร้างภายในรั่วไหล
  * **Cryptographic Random Passwords:** สุ่มรหัสผ่านชั่วคราวด้วย `System.Security.Cryptography.RandomNumberGenerator` ซึ่งปลอดภัยระดับที่ Source Code Scanner ยอมรับ (ผ่านฉลุยบน GitHub)
  * **Secure Credential Caching:** เก็บแคชการล็อกอิน (Remember me) ไว้ในพื้นที่ส่วนตัวของผู้ใช้ (`LocalAppData`) แทนโฟลเดอร์สาธารณะ
  * **Binary Planting Protection:** ป้องกันการถูกสวมรอยไฟล์รันไทม์ (Malware placement) โดยจำกัดพื้นที่การคัดลอกไฟล์
* **Account Management:** 
  * รีเซ็ตรหัสผ่านแบบกำหนดเอง (Custom) หรือแบบสุ่มชั่วคราว (Random Temp - บังคับเปลี่ยนเมื่อล็อกอินครั้งถัดไป)
  * เพิ่ม/ลบ สิทธิ์ผู้ใช้เข้ากลุ่ม `Local_Admin` ได้ด้วยคลิกเดียว
* **Computer Diagnostics:** ตรวจสอบสถานะ AD (Joined/Unjoined), IP Address, วันที่ล็อกอินล่าสุด และดึงรายชื่อ Local User Profiles ภายในเครื่อง (อ่านจาก `C$\Users`)
* **Built-in Activity Logging:** มีระบบบันทึก Log การทำงานภายในแอปเพื่อให้ตรวจสอบย้อนหลังได้

## 📋 Prerequisites (สิ่งที่ต้องมี)
1. เครื่องคอมพิวเตอร์ที่รันโปรแกรมต้อง Join Domain แล้ว 
2. ติดตั้ง RSAT: Active Directory Domain Services and Lightweight Directory Tools บน Windows
3. สิทธิ์ Domain Admin หรือสิทธิ์ที่ได้รับมอบหมาย (Delegated) ในการจัดการ AD

## 🚀 How to build into .exe (การแปลงไฟล์เป็น .exe)
เพื่อให้ผู้ใช้งานทั่วไปเรียกใช้โปรแกรมได้ง่ายขึ้นโดยไม่ต้องคลิกขวา Run with PowerShell คุณสามารถแปลงไฟล์ .ps1 เป็นไฟล์ .exe ได้โดยใช้โมดูล ps2exe

ขั้นตอนการทำ:

1. เปิด PowerShell (Run as Administrator)
2. ติดตั้งโมดูล ps2exe (ทำแค่ครั้งแรกครั้งเดียว):
   ```bash
   Install-Module -Name ps2exe -Scope CurrentUser -Force
   ```
4. รันคำสั่งแปลงไฟล์ (นำไฟล์ไปไว้ในโฟลเดอร์เดียวกันก่อนรัน):
   ```bash
   Invoke-ps2exe -InputFile ".\AD_Helpdesk_Tools.ps1" -OutputFile ".\ADHelpdeskTool.exe" -NoConsole
   ```
(หมายเหตุ: การใช้ Flag -NoConsole จะช่วยซ่อนหน้าต่างหน้าจอดำ (CMD) ไว้เบื้องหลัง ทำให้แสดงผลเฉพาะหน้าต่าง GUI ของโปรแกรมเท่านั้น)

5. (Optional) หากต้องการใส่ไอคอนให้กับโปรแกรม ให้เตรียมไฟล์ .ico ไว้และใช้คำสั่งนี้:
   ```bash
   Invoke-ps2exe -InputFile ".\AD_Helpdesk_Tools.ps1" -OutputFile ".\ADHelpdeskTool.exe" -NoConsole -IconFile ".\your_icon.ico"
   ```
## ⚠️ Disclaimer
โปรดใช้งานอย่างระมัดระวัง ฟีเจอร์บางอย่างเช่นการมอบสิทธิ์ Local_Admin ควรกระทำภายใต้นโยบายความปลอดภัยขององค์กร (Company Policy) อย่างเคร่งครัด
