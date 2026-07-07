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
