// 可放 JSON 陣列；若為空字串，將改用下面的 Comet 條列文字解析。
const String shopSeedJson = '';

// 直接貼 Comet 條列格式（以空行分隔商品）。每筆在連結（或裸網址）下一行寫「imgURL:」再自行貼 https 圖址；舊「圖片：」解析仍支援。
const String shopSeedCometText = r'''
【一匙靈】制菌超濃縮洗衣精補充包 1.9kg×6包
首購價：$248（原價 $510）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7830
imgURL:https://i4.momoshop.com.tw/1775556841/goodsimg/0005/534/801/5534801_B.webp

【橘子工坊】天然濃縮洗衣精-制菌洗淨病毒 1500ml×6包
首購價：$681（原價 $1,500）箱購
連結：https://pxbox.es.pxmart.com.tw/product/8012
imgURL:https://i4.momoshop.com.tw/1773657181/goodsimg/0007/529/487/7529487_R.webp

【ARIEL】抗菌洗衣精/洗衣液補充包-抗菌去漬 1690g×6包
首購價：$999（原價 $1,884）箱購
連結：https://pxbox.es.pxmart.com.tw/product/89582
imgURL:https://online.carrefour.com.tw/on/demandware.static/-/Sites-carrefour-tw-m-inner/default/dw2b6b313d/images/large/1110323900101_NR_00.jpg

【ARIEL】抗菌洗衣精/洗衣液補充包-室內晾衣 1690g×6包
首購價：$999（原價 $1,884）箱購
連結：https://pxbox.es.pxmart.com.tw/product/89584
imgURL:https://img.pchome.com.tw/cs/items/DAAK7P1900IBNVW/000001_1744645876.png

【ARIEL】抗菌洗衣精/洗衣液補充包-高效除瞞 1690g×6包
首購價：$999（原價 $1,884）箱購
連結：https://pxbox.es.pxmart.com.tw/product/89586
imgURL:https://img.pchome.com.tw/cs/items/DAAK7P1900IBNVW/000001_1744645876.png

【ARIEL】抗菌洗衣精/洗衣液補充包-自然微香 1690g×6包
首購價：$999（原價 $1,884）箱購
連結：https://pxbox.es.pxmart.com.tw/product/89588
imgURL:https://img.pchome.com.tw/cs/items/DAAK7P1900IBNVW/000001_1744645876.png

【ARIEL】抗菌洗衣精/洗衣液補充包-抗菌去漬（1690g 單包）
首購價：$202（原價 $314）
連結：https://pxbox.es.pxmart.com.tw/product/89590
imgURL:https://pcm3.trplus.com.tw/1000x1000/sys-master/productImages/h91/hb9/12675967221790/000000000016803541-gallery-01-20260226150611483.jpg

【ARIEL】抗菌洗衣精/洗衣液補充包-室內晾衣（1690g 單包）
首購價：$202（原價 $314）
連結：https://pxbox.es.pxmart.com.tw/product/89592
imgURL:https://pcm3.trplus.com.tw/1000x1000/sys-master/productImages/h91/hb9/12675967221790/000000000016803541-gallery-01-20260226150611483.jpg

【ARIEL】抗菌洗衣精/洗衣液補充包-高效除瞞（1690g 單包）
首購價：$202（原價 $314）
連結：https://pxbox.es.pxmart.com.tw/product/89594
imgURL:https://pcm3.trplus.com.tw/1000x1000/sys-master/productImages/h91/hb9/12675967221790/000000000016803541-gallery-01-20260226150611483.jpg

【ARIEL】抗菌洗衣精/洗衣液補充包-自然微香（1690g 單包）
首購價：$202（原價 $314）
連結：https://pxbox.es.pxmart.com.tw/product/89596
imgURL:https://pcm3.trplus.com.tw/1000x1000/sys-master/productImages/h91/hb9/12675967221790/000000000016803541-gallery-01-20260226150611483.jpg

【ARIEL】抗菌洗衣精/洗衣液-室內晾衣（890g）
售價：$129
連結：https://pxbox.es.pxmart.com.tw/product/89598
imgURL:https://online.carrefour.com.tw/on/demandware.static/-/Sites-carrefour-tw-m-inner/default/dw225c3644/images/large/1110324100101_NR_00.jpg

【ARIEL】抗菌洗衣精/洗衣液-高效除瞞（890g）
售價：$129
連結：https://pxbox.es.pxmart.com.tw/product/89600
imgURL:https://encrypted-tbn2.gstatic.com/shopping?q=tbn:ANd9GcQgUfugEqqaojNZs5sBNsIS9n7NWRm284rzyNi_IsIo1gAQq01r0ta2KohTz6fmi0Ml9aw8MYpcDR0CL_vCWrBf_Ggxliv6yfrUmjFHnwy_o4MUfjG_xN_JpDGWhqsYs-Y2q5X-atY&usqp=CAc

【依必朗】防霉抗菌洗衣精-陽光香氛 4000g×4瓶
首購價：$305（原價 $596）箱購
連結：https://pxbox.es.pxmart.com.tw/product/10038
imgURL:https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ6SDFWw1jQiQ22mnlT6CI1XTEResOavC9PoQ&s

【依必朗】防霉抗菌洗衣精補充包-茶花香氛 1800g×8包
首購價：$321（原價 $872）箱購
連結：https://pxbox.es.pxmart.com.tw/product/10040
imgURL:https://encrypted-tbn3.gstatic.com/shopping?q=tbn:ANd9GcTgjNeu1YQNR_ey52lg8SXwtI3625P45RAxfBp7vcGUoGhbDhRzjhBQTWdopHrirqKHKpK6sdch7w-cZ9B9w-Nic2WllnND0-agvHma9FmG8FQLXXImWYi0HRAU38UIyXoP67StUg&usqp=CAc

【依必朗】防霉抗菌洗衣精-芬多精（2300g）
售價：$69
連結：https://pxbox.es.pxmart.com.tw/product/10042
imgURL:https://th.bing.com/th/id/OIP.vU-mvqXWFkMWc0yCYg0GiAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】抗菌EX強力消臭洗衣精補充包 1.5kg×6包
首購價：$332（原價 $510）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7832
imgURL:https://th.bing.com/th/id/OIP.91qaK_T4DiALRRMWkRO0-wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】抗菌EX室內晾衣洗衣精補充包 1.5kg×6包
首購價：$332（原價 $510）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7834
imgURL:https://th.bing.com/th/id/OIP.kCPdaeGJrnQDKNWhVk9qUAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】抗菌EX防蹣成分PLUS洗衣精 2.4kg×6瓶
首購價：$694（原價 $942）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7836
imgURL:https://th.bing.com/th/id/OIP.R6H99lWGc0HxUGM57jk6NwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】抗菌EX強力消臭洗衣精瓶裝 2.4kg×6瓶
首購價：$694（原價 $942）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7838
imgURL:https://th.bing.com/th/id/OIP.idlk4oJNaG8_XHGD5VzSZgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】抗菌EX植萃低敏洗衣精補充包 1.5kg×6包
首購價：$332（原價 $510）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7840
imgURL:https://th.bing.com/th/id/OIP.GwzeRhxyUMphEJjwEuntygHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】淨柔超濃縮洗衣精補充包 1.8kg×6包
首購價：$248（原價 $510）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7842
imgURL:https://th.bing.com/th/id/OIP.ddQgoGZI9CNEHWufaaB0DgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】歡馨香氛洗衣精補充包-幽谷鈴蘭 1.5kg×6包
首購價：$290（原價 $510）箱購
連結：https://pxbox.es.pxmart.com.tw/product/7844
imgURL:https://th.bing.com/th/id/OIP.oPxMo7LPYVvBqK-eOyULSAHaFD?w=277&h=189&c=7&r=0&o=7&pid=1.7&rm=3

【一匙靈】制菌超濃縮洗衣精補充包（1.7kg）
售價：$89（原價 $107）
連結：https://pxbox.es.pxmart.com.tw/product/7846
imgURL:https://th.bing.com/th/id/OIP.RWT73osqUCQN-amcfdzLYgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】含熊寶貝精華洗衣精補充包-大自然馨香 1.6kg×6包
首購價：$321（原價 $666）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5380
imgURL:https://th.bing.com/th/id/OIP.fHzQtWC0R1DNyDKbZ-INawHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】洗衣精補充包(含熊寶貝馨香精華)-質感小倉蘭 1.6kg×6包
首購價：$321（原價 $666）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5382
imgURL:https://th.bing.com/th/id/OIP.fHzQtWC0R1DNyDKbZ-INawHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】強效潔淨超濃縮洗衣精補充包 1.6kg×6包
首購價：$302（原價 $552）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5384
imgURL:https://th.bing.com/th/id/OIP.fHzQtWC0R1DNyDKbZ-INawHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】超濃縮洗衣精含熊寶貝馨香精華-陽光金橙 1.5kg×6包
首購價：$290（原價 $846）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5386
imgURL:https://th.bing.com/th/id/OIP.fHzQtWC0R1DNyDKbZ-INawHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】強效潔淨超濃縮洗衣精 2.7kg×4瓶
首購價：$389（原價 $688）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5388
imgURL:https://th.bing.com/th/id/OIP.w9JsAeZ6UAXvUINxBPBvoAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】含熊馨香精華花漾清新洗衣精（2.5kg）
首購價：$104（原價 $201）
連結：https://pxbox.es.pxmart.com.tw/product/5390
imgURL:https://th.bing.com/th/id/OIP.Fp9xZc_TrgeVtG54mVDWewHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】含熊澄淨玫瑰X青檸洗衣精（2.5kg）
首購價：$104（原價 $201）
連結：https://pxbox.es.pxmart.com.tw/product/5392
imgURL:https://th.bing.com/th/id/OIP.S5TLfWHYSB1JF3EJ4kFF-AHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】含熊馨香精華大自然馨香洗衣精（2.5kg）
首購價：$104（原價 $201）
連結：https://pxbox.es.pxmart.com.tw/product/5394
imgURL:https://th.bing.com/th/id/OIP.Fp9xZc_TrgeVtG54mVDWewHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】含熊馨香精華純淨溫和洗衣精（2.5kg）
首購價：$104（原價 $201）
連結：https://pxbox.es.pxmart.com.tw/product/5396
imgURL:https://th.bing.com/th/id/OIP.Fp9xZc_TrgeVtG54mVDWewHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】洗衣精-強效除蹣過敏（2.7kg）
售價：$139
連結：https://pxbox.es.pxmart.com.tw/product/5398
imgURL:https://th.bing.com/th/id/OIP.Vj88UbICqTuTVIyz6u26_gHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】洗衣精補充包-強效除蹣過敏（1.6kg）
售價：$76
連結：https://pxbox.es.pxmart.com.tw/product/5400
imgURL:https://th.bing.com/th/id/OIP.EZn-wUxC6zJhiev6pISIMgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白蘭】4X極淨酵素抗病毒洗衣精補充包 1.5kg×6包
首購價：$405（原價 $1,074）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5402
imgURL:https://th.bing.com/th/id/OIP.CvNj8NkCC8AQ9I2nG3NLQwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白鴿】天然濃縮防蹣抗菌洗衣精補充包-天然尤加利 2000g×6包
首購價：$416（原價 $690）箱購
連結：https://pxbox.es.pxmart.com.tw/product/8760
imgURL:https://th.bing.com/th/id/OIP.cSnJKYnBF80vWwtRtWp2ewHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白鴿】天然濃縮防蹣抗菌洗衣精-天然尤加利 3500g×4瓶
首購價：$596（原價 $816）箱購
連結：https://pxbox.es.pxmart.com.tw/product/8762
imgURL:https://th.bing.com/th/id/OIP.KQJQ_r5EliGKkkJ2Mp8LbwHaIN?w=187&h=207&c=7&r=0&o=7&pid=1.7&rm=3

【白鴿】天然濃縮防霉抗菌洗衣精-天然香蜂草 3500g×4瓶
首購價：$596（原價 $816）箱購
連結：https://pxbox.es.pxmart.com.tw/product/8764
imgURL:https://th.bing.com/th/id/OIP.fjuxxgiJQ-RQWPlGHfyKuAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白鴿】天然濃縮護纖抗菌洗衣精補充包-天然棉花籽 2000g×6包
首購價：$416（原價 $690）箱購
連結：https://pxbox.es.pxmart.com.tw/product/8766
imgURL:https://th.bing.com/th/id/OIP.F3-qNfP0OcnTAUTBe3GfKQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白鴿】防霉抗菌洗衣精（3500g）
首購價：$132（原價 $204）
連結：https://pxbox.es.pxmart.com.tw/product/8768
imgURL:https://th.bing.com/th/id/OIP.TCsajG14QUa2RoY85RuGHwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【毛寶】全效強淨柔軟洗衣精-梔子花香 3500g×4瓶
首購價：$307（原價 $636）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5422
imgURL:https://th.bing.com/th/id/OIP.GIvXWhdVvWjg1Jl3AVJmdwAAAA?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【毛寶】全效增豔柔軟洗衣精-溫暖花果香 3500g×4瓶
首購價：$307（原價 $636）箱購
連結：https://pxbox.es.pxmart.com.tw/product/5424
imgURL:https://th.bing.com/th/id/OIP.GIvXWhdVvWjg1Jl3AVJmdwAAAA?w=204&h=204&c=7&r=0&o=7&pid=1.7&rm=3

【毛寶】除霉防蟎抗菌PM2.5洗衣精-瓶裝（2200g）
售價：$99（原價 $135）
連結：https://pxbox.es.pxmart.com.tw/product/5426
imgURL:https://th.bing.com/th/id/OIP.w_Yo0LYVMB7396_pWuGbUAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【毛寶】葳香抗菌洗衣精-防霉淨味-瓶裝（3000g）
售價：$139
連結：https://pxbox.es.pxmart.com.tw/product/5428
imgURL:https://th.bing.com/th/id/OIP.2tk3c7qasGfUAmeIPSULJAHaHa?w=220&h=220&c=7&r=0&o=7&pid=1.7&rm=3

【古寶無患子】萬用清潔劑(500g)
售價：$265（原價 $459）
連結：https://pxbox.es.pxmart.com.tw/product/196219
imgURL:https://th.bing.com/th/id/OIP.2cJpuhr24qfbFKsnxuBeeQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【古寶無患子】神奇檸檬泡沫水垢清潔劑(500g)
首購價：$139（原價 $287）
連結：https://pxbox.es.pxmart.com.tw/product/88349
imgURL:https://th.bing.com/th/id/OIP.k5okRoV_lKIC69pmG0inVgHaHa?w=188&h=188&c=7&r=0&o=7&pid=1.7&rm=3

【益富】益力壯給力優蛋白高鈣配方-原味無糖(250ml×24罐)
售價：$1,550（頁面同價）
連結：https://pxbox.es.pxmart.com.tw/product/432202
imgURL:https://th.bing.com/th/id/OIP.HCn21QvHrva9C5nv75BVxwHaHa?w=201&h=201&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素3重優蛋白(250ml×24入)
首購價：$1,410（原價 $1,750）
連結：https://pxbox.es.pxmart.com.tw/product/161504
imgURL:https://th.bing.com/th/id/OIP.fdVW1KHUaceDQfBOc1NJrgHaHa?w=196&h=196&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素全新均衡營養配方(850g)
首購價：$462（原價 $695）
連結：https://pxbox.es.pxmart.com.tw/product/16549
imgURL:https://th.bing.com/th/id/OIP.Idn3monj9a78so-N5KUegAHaGT?w=230&h=195&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素均衡營養升級配方-原味(237ml×14入)
首購價：$799（原價 $1,069）
連結：https://pxbox.es.pxmart.com.tw/product/89552
imgURL:https://th.bing.com/th/id/OIP.hKw-8DuPoy1OVgbn0xTtOwHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素優能基均衡營養配方促銷組-香草少甜(800g×2入)
首購價：$1,470（原價 $1,784）
連結：https://pxbox.es.pxmart.com.tw/product/89558
imgURL:https://th.bing.com/th/id/OIP.JOy5a7WbcJVOPOxn8Th6VgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【補體素】優蛋白 原味-即飲配方食品 237ml×24罐
售價：$1,550（原價 $1,584）
連結：https://pxbox.es.pxmart.com.tw/product/2345
imgURL:https://th.bing.com/th/id/OIP.-yH9lgl3Ilpec5duNqpzBgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素原味HMB升級配方(237ml×24入)
首購價：$1,500（原價 $1,700）
連結：https://pxbox.es.pxmart.com.tw/product/89540
imgURL:https://th.bing.com/th/id/OIP.YuiPc-lMvIf6vgn7KfDhFAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【益富】益力壯順力雙好菌高鈣配方(850g)
首購價：$639（原價 $890）
連結：https://pxbox.es.pxmart.com.tw/product/142428
imgURL:https://th.bing.com/th/id/OIP.T-9MMWNUHIGXxOGdlwvEvAAAAA?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素-高鈣配方(237ml×24入)
售價：$1,550（原價 $1,580）
連結：https://pxbox.es.pxmart.com.tw/product/72467
imgURL:https://th.bing.com/th/id/OIP.fdVW1KHUaceDQfBOc1NJrgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素HMB升級配方香草減甜口味(237ml×24入)
首購價：$1,500（原價 $1,700）
連結：https://pxbox.es.pxmart.com.tw/product/89549
imgURL:https://th.bing.com/th/id/OIP.5W9FSgRpwDVipv9D475d2gHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【補體素】優蛋白-原味(750g)
售價：$660（原價 $680）
連結：https://pxbox.es.pxmart.com.tw/product/179985
imgURL:https://th.bing.com/th/id/OIP.GIa59sEuosmWJj7tIwNu1wHaE7?w=300&h=200&c=7&r=0&o=7&pid=1.7&rm=3

【補體素】優纖A+均衡營養配方(900g)
售價：$660（原價 $680）
連結：https://pxbox.es.pxmart.com.tw/product/179991
imgURL:https://th.bing.com/th/id/OIP.sVXjB7FFaHw7K4V8Ji5a7wHaHa?w=220&h=220&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素100鉻含纖配方(237ml×24入)
首購價：$1,750（原價 $2,105）
連結：https://pxbox.es.pxmart.com.tw/product/72465
imgURL:https://th.bing.com/th/id/OIP.KDkbfA4ypcdmgepvbI_SZgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【克寧】全家三倍鈣營養奶粉(2.2kg)
首購價：$384（原價 $599）
連結：https://pxbox.es.pxmart.com.tw/product/5032
imgURL:https://th.bing.com/th/id/OIP.nt0697OMeNFXWgCdfDfe3AHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素含白藜蘆醇(237ml×24瓶/箱)
首購價：$1,300（原價 $1,540）
連結：https://pxbox.es.pxmart.com.tw/product/18118
imgURL:https://th.bing.com/th/id/OIP.DqQbbhiqPj-dhJKyxSAjIwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【安怡】優蛋白高鈣營養配方 760g×6罐
首購價：$2,797（原價 $6,594，箱購）
連結：https://pxbox.es.pxmart.com.tw/product/218672
imgURL:https://th.bing.com/th/id/OIP.mGInYZxMBnFn0O2yB_YlVgHaHa?w=210&h=210&c=7&r=0&o=7&pid=1.7&rm=3

【益富】益力壯給力乳清蛋白高鈣配方(750g)
首購價：$445（原價 $890）
連結：https://pxbox.es.pxmart.com.tw/product/142426
imgURL:https://th.bing.com/th/id/OIP._CLSNVDcmZiD9EJhPJcIQgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【ASAHI 朝日】筋骨葡萄糖胺軟骨素(720粒)
首購價：$1,340（原價 $2,310）
連結：https://pxbox.es.pxmart.com.tw/product/337967
imgURL:https://th.bing.com/th/id/OIP.AmYC3UsqHeA0-9XpcEP1MgHaHa?w=212&h=212&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素 原味無糖(250ml×8入)
首購價：$354（原價 $532）
連結：https://pxbox.es.pxmart.com.tw/product/7713
imgURL:https://th.bing.com/th/id/OIP.0WApbiyw006fgZng57hmaQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【快樂田生技】全養沛-植物蛋白均衡營養配方-燕麥風味(全素/無果糖)(237ml×12入)
首購價：$518（原價 $798）
連結：https://pxbox.es.pxmart.com.tw/product/294171
imgURL:https://th.bing.com/th/id/OIP.0ON1yTvk_OOy4BxJ3zq0sAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素優能基均衡營養配方-香草少甜口味(800g)
首購價：$645（原價 $890）
連結：https://pxbox.es.pxmart.com.tw/product/89545
imgURL:https://th.bing.com/th/id/OIP.d3jlHeU23cdWOoeKPs8SPQAAAA?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】預購完膳營養素原味無糖(250ml×24入)
售價：$1,390（原價同為 $1,390，指定預購）
連結：https://pxbox.es.pxmart.com.tw/product/339400
imgURL:https://th.bing.com/th/id/OIP.q1NouLXgcNd5QROjm90PkAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【補體素】優蛋白-香草(750g)
售價：$660（原價 $680）
連結：https://pxbox.es.pxmart.com.tw/product/179992
imgURL:https://th.bing.com/th/id/OIP.zuzQjZMKRdCyDbtytIbQEQHaHa?w=176&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【益富】益力壯乳清蛋白高鈣配方-給力 750g×6罐
售價：$3,750（原價 $5,340，箱購）
連結：https://pxbox.es.pxmart.com.tw/product/117887
imgURL:https://th.bing.com/th/id/OIP.GLOXPeoH9D1aV3zVuptRlQHaHa?w=183&h=183&c=7&r=0&o=7&pid=1.7&rm=3

【SENTOSA 三多】補体康均衡配方(865g/罐)
售價：$531（原價 $630）
連結：https://pxbox.es.pxmart.com.tw/product/7736
imgURL:https://th.bing.com/th/id/OIP.cRUdTde5QbYOWxqiaxCOgwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Stemtech】RCM禮盒＋SR3(3瓶/共300顆)
售價：$3,899（原價 $6,888）
連結：https://pxbox.es.pxmart.com.tw/product/671403
imgURL:https://th.bing.com/th/id/OIP.imlMti6MSm1LdGrJNEIwrAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【永信HAC】綜合維他命軟膠囊(100粒)
首購價：$448（原價 $800）
連結：https://pxbox.es.pxmart.com.tw/product/184606
imgURL:https://th.bing.com/th/id/OIP.QqXzFAkSk-7zeqxjKsldLgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【益富】益力壯美力膠原蛋白高鈣配方-紅豆 237ml×24罐
首購價：$1,350（原價 $1,550，箱購）
連結：https://pxbox.es.pxmart.com.tw/product/224357
imgURL:https://th.bing.com/th/id/OIP.GfEirm5A3yNzvk2DxbvPVwAAAA?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素含白藜蘆醇配方(237ml×6瓶/盒)
首購價：$273（原價 $411）
連結：https://pxbox.es.pxmart.com.tw/product/18054
imgURL:https://th.bing.com/th/id/OIP.qH2CRzaSQuPvRMOfi0nVFgHaHa?w=176&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素優能基HMB升級配方-穀物口味(800g)
首購價：$669（原價 $890）
連結：https://pxbox.es.pxmart.com.tw/product/89542
imgURL:https://th.bing.com/th/id/OIP.8dHYF2QdjhS11CGQX77RqQHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素均衡營養升級配方-原味 237ml×24入
售價：$1,700（原價同為 $1,700，箱購）
連結：https://pxbox.es.pxmart.com.tw/product/122899
imgURL:https://th.bing.com/th/id/OIP.xu1j0V6hLty5cojPn61LwQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素優能基 HMB升級配方促銷組-香草口味(800g×2入)
首購價：$1,520（原價 $1,784）
連結：https://pxbox.es.pxmart.com.tw/product/89544
imgURL:https://th.bing.com/th/id/OIP.eeQBi6ylSwC1IQ4eiHbKrwHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【快樂田生技】全養沛-植物蛋白高鈣營養配方-燕麥風味(低糖/全素)(237ml×12入)
首購價：$540（原價 $822）
連結：https://pxbox.es.pxmart.com.tw/product/294170
imgURL:https://th.bing.com/th/id/OIP.0ON1yTvk_OOy4BxJ3zq0sAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【台糖】大豆卵磷脂(200g)
首購價：$144（原價 $220）
連結：https://pxbox.es.pxmart.com.tw/product/24590
imgURL:https://th.bing.com/th/id/OIP.C_gWi5T7rrxQ6YjZCD0QUQAAAA?w=204&h=204&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素3重優蛋白(250ml×6罐)
首購價：$288（原價 $457）
連結：https://pxbox.es.pxmart.com.tw/product/157865
imgURL:https://th.bing.com/th/id/OIP.0ixLGcDpYwbUQDKw_2I79QHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【紅牛】全家人高鈣奶粉-膠原蛋白配方(2.2kg)
首購價：$346（原價 $552）
連結：https://pxbox.es.pxmart.com.tw/product/5659
imgURL:https://th.bing.com/th/id/OIP.8Wmo-dXSLTCpae2msRpqcAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【SENTOSA 三多】補体康C經典營養配方(240ml×24罐)
售價：$1,029（原價同為 $1,029）
連結：https://pxbox.es.pxmart.com.tw/product/8848
imgURL:https://th.bing.com/th/id/OIP.60ssPvhlUOsLnQ1ogNqeoQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【SENTOSA 三多】補体康HN均衡營養配方(240ml×24罐)
售價：$1,122（原價 $1,320）
連結：https://pxbox.es.pxmart.com.tw/product/157863
imgURL:https://th.bing.com/th/id/OIP.cF7pIfsabeaKawdZgKWGKwHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素含纖原味(250ml×24入)
首購價：$1,220（原價 $1,540）
連結：https://pxbox.es.pxmart.com.tw/product/18117
imgURL:https://th.bing.com/th/id/OIP.q1NouLXgcNd5QROjm90PkAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【迪卡儂】左旋肉酸(120顆/瓶)
首購價：$279（原價 $399）
連結：https://pxbox.es.pxmart.com.tw/product/33580
imgURL:https://th.bing.com/th/id/OIP.8G56ZROt3wyJn_hv8PGawwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素穩健配方(900g)
售價：$809（原價 $1,057）
連結：https://pxbox.es.pxmart.com.tw/product/18111
imgURL:https://th.bing.com/th/id/OIP.ZndnBOQf6iZb0Bu7uCUEMAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素沛力優蛋白配方減甜24入(237ml×24)
首購價：$1,709（原價 $1,945）
連結：https://pxbox.es.pxmart.com.tw/product/178231
imgURL:https://th.bing.com/th/id/OIP.Z17Amj_XAxYcnWQZtsZk9wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素香草低糖少甜(250ml×24入)
首購價：$1,220（原價 $1,540）
連結：https://pxbox.es.pxmart.com.tw/product/7712
imgURL:https://th.bing.com/th/id/OIP.iljZhgjp8lF5-qaPhZaHAgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【桂格】完膳營養素-50鉻配方24入
首購價：$1,700（原價 $2,105）
連結：https://pxbox.es.pxmart.com.tw/product/18124
imgURL:https://th.bing.com/th/id/OIP.6bI7h-6KQ2tbvzB6CDPkUAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素均衡營養升級配方-香草減甜口味 237ml×24入
售價：$1,700（原價同為 $1,700，箱購）
連結：https://pxbox.es.pxmart.com.tw/product/122901
imgURL:https://th.bing.com/th/id/OIP.xu1j0V6hLty5cojPn61LwQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素營養升級配方香草減甜14入(237ml×14)
售價：$999（原價 $1,069）
連結：https://pxbox.es.pxmart.com.tw/product/89554
imgURL:https://th.bing.com/th/id/OIP.YzHq3ZvzX73HTg_jjxCBvAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【豐力富】全家人高鈣營養奶粉(2.2kg)
首購價：$384（原價 $627）
連結：https://pxbox.es.pxmart.com.tw/product/5061
imgURL:https://th.bing.com/th/id/OIP.LSGfJAoxe3RguKwgDaiZUAHaHa?w=212&h=212&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素高鈣鈣強化配方減甜8入禮盒(237ml×8)
售價：$669（原價 $705）
連結：https://pxbox.es.pxmart.com.tw/product/178232
imgURL:https://th.bing.com/th/id/OIP.CtIv2nvGainEeG9sVdetQAHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【亞培】安素高鈣鈣強化配方減甜8入禮盒(237ml×8)
售價：$79（原價 $89）
連結：https://pxbox.es.pxmart.com.tw/product/33322
imgURL:https://th.bing.com/th/id/OIP.-S0YOSnwzAi0XSHzg3t4ygHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【魔術靈】廚房清潔劑(3.8L/瓶)
首購價：$139（原價 $305）
連結：https://pxbox.es.pxmart.com.tw/product/5502
imgURL:https://th.bing.com/th/id/OIP.xSVmgOd-vsyBoxnQQA2IPwHaHa?w=212&h=212&c=7&r=0&o=7&pid=1.7&rm=3

【魔術靈】浴室清潔劑(3800ml)
首購價：$139（原價 $305）
連結：https://pxbox.es.pxmart.com.tw/product/10192
imgURL:https://th.bing.com/th/id/OIP.SDp8v4LS0pjNypbdolWQ5AHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【魔術靈】免刷雙效淨垢泡馬桶清潔劑(40g×3包)
售價：$149（原價 $180）
連結：https://pxbox.es.pxmart.com.tw/product/529054
imgURL:https://th.bing.com/th/id/OIP.ia-ByplXrTjeGcSyA26fiQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【潔霜】S浴廁清潔劑桶裝-潔淨杏香(3800g)
首購價：$111（原價 $199）
連結：https://pxbox.es.pxmart.com.tw/product/6086
imgURL:https://th.bing.com/th/id/OIP.kf-tqNhCMaVmH6EN8_GaAgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【CEETOON】多功能魔術萬用清潔去污膏500g_贈海綿刷(1入組)
首購價：$202（原價 $690）
連結：https://pxbox.es.pxmart.com.tw/product/40130
imgURL:https://th.bing.com/th/id/OIP.ZRwhZmE2doJQU0KrfHOUSAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【古寶無患子】神奇檸檬洗衣槽清潔劑(200g×3入)
售價：$189（原價 $350）
連結：https://pxbox.es.pxmart.com.tw/product/426809
imgURL:https://th.bing.com/th/id/OIP.t8uxLYsawPPBSm6vQ9Yo7wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【clorox 高樂氏】萬用去汙清潔劑-雨林香(946ml/瓶)
首購價：$106（原價 $159）
連結：https://pxbox.es.pxmart.com.tw/product/10360
imgURL:https://th.bing.com/th/id/OIP.sRU9MGhsYy48I7ntsyRhowHaHa?w=215&h=215&c=7&r=0&o=7&pid=1.7&rm=3

【HouseKeeper 妙管家】瞬潔地板清潔劑(1800g)
售價：$99（原價 $189）
連結：https://pxbox.es.pxmart.com.tw/product/18366
imgURL:https://th.bing.com/th/id/OIP.k9cnFDg-S3Ij5Oo-l0xO2QHaHa?w=183&h=183&c=7&r=0&o=7&pid=1.7&rm=3

【威猛先生】浴室清潔劑一除垢(500g)
售價：$65（原價 $69）
連結：https://pxbox.es.pxmart.com.tw/product/178245
imgURL:https://th.bing.com/th/id/OIP.bMDf-qqYva091JIT2hlDGAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【WASHWISE 聰明洗】家用安心清潔四件組(8000ml)
首購價：$1,480（原價 $1,680）
連結：https://pxbox.es.pxmart.com.tw/product/589655
imgURL:https://th.bing.com/th/id/OIP.TMow_uXwFQcIS46xZ1z7EwHaD4?w=295&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【MarkRon】強效萬用泡沫清潔劑(650ml×1罐)
售價：$149（原價 $149）
連結：https://pxbox.es.pxmart.com.tw/product/30424
imgURL:https://th.bing.com/th/id/OIP.M1PNkzDdVfdhm1XcdvR62AHaHa?w=201&h=201&c=7&r=0&o=7&pid=1.7&rm=3

【clorox 高樂氏】洗衣機槽清潔消毒劑(500ml)
售價：$99（原價 $199）
連結：https://pxbox.es.pxmart.com.tw/product/429893
imgURL:https://th.bing.com/th/id/OIP.v_hgALI2MHFvx6j4Ksn6PwAAAA?w=132&h=217&c=7&r=0&o=7&pid=1.7&rm=3

【SPARTAN 斯巴達】BioBowl益菌式表裡淨化浴廁清潔劑環保專業版(946ml)
折後價：$660（原價 $1,490）
連結：https://pxbox.es.pxmart.com.tw/product/44422
imgURL:https://th.bing.com/th/id/OIP.ugdbiSOM30wIse1rHVBIQgAAAA?w=174&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【優思居】日本熱銷免拆洗紗窗強力清潔劑 超值2入(360ml)
首購價：$189（原價 $600）
連結：https://pxbox.es.pxmart.com.tw/product/165059
imgURL:https://th.bing.com/th/id/OIP.7oaGIM76SzVAuXhzPgVCWQHaHZ?w=204&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Castle 家適多】專業地毯沙發清潔劑 500ml(1入)
首購價：$349（原價 $499）
連結：https://pxbox.es.pxmart.com.tw/product/258798
imgURL:https://th.bing.com/th/id/OIP.alyFA9SNLi0Jw8gVpxLwYAHaHa?w=194&h=194&c=7&r=0&o=7&pid=1.7&rm=3

【橘子工坊】天然廚房去油清潔劑(480ml)
售價：$130（原價 $135）
連結：https://pxbox.es.pxmart.com.tw/product/10375
imgURL:https://th.bing.com/th/id/OIP.BdHWyVbSl2hDwSYLtV6KTwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【衣麗亮白】強中強去油污清潔慕斯 520ml
售價：$199（原價 $899）
連結：https://pxbox.es.pxmart.com.tw/product/377318
imgURL:https://th.bing.com/th/id/OIP._ytqOUv-HGLYSajfOVJLMQHaFj?w=247&h=185&c=7&r=0&o=7&pid=1.7&rm=3

【生活良好】清潔海綿-排水佳(1入裝)
售價：$29（原價 $39）
連結：https://pxbox.es.pxmart.com.tw/product/112643
imgURL:https://th.bing.com/th/id/OIP.CDloJHfHjlGCp_ecSAZG8wHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【白博士】白博士廚房清潔劑噴槍型(600g)
售價：$68（原價 $72）
連結：https://pxbox.es.pxmart.com.tw/product/68891
imgURL:https://th.bing.com/th/id/OIP.ElzHPIHkSAcQjt-DKxF_iQHaLI?w=143&h=215&c=7&r=0&o=7&pid=1.7&rm=3

【魔術靈】高密泡馬桶清潔劑 柑橘消臭 噴槍瓶(500ml)
售價：$79（原價 $89）
連結：https://pxbox.es.pxmart.com.tw/product/33327
imgURL:https://th.bing.com/th/id/OIP.BNLL1LZ8sQ0qIYSB0qiPkAHaHa?w=211&h=211&c=7&r=0&o=7&pid=1.7&rm=3

【優思居】日式可伸縮無死角萬用清潔刷(1入)
售價：$254（原價 $500）
連結：https://pxbox.es.pxmart.com.tw/product/152955
imgURL:https://th.bing.com/th/id/OIP.lMAC2ksYhyWe7Pn5MDqBJgHaL-?w=134&h=217&c=7&o=7&pid=1.7&rm=3&retry=2

【綠綠好日】廚房油污清潔劑(二入)
首購價：$549（原價 $998）
連結：https://pxbox.es.pxmart.com.tw/product/670029
imgURL:https://th.bing.com/th/id/OIP.U0Uy5ZHkQ_xmi_X8tUw7lgHaHa?w=203&h=203&c=7&o=7&pid=1.7&rm=3&retry=2

【SINYI】實用型洗車清潔工具8件組(1組入)
售價：$269（原價 $269）
連結：https://pxbox.es.pxmart.com.tw/product/41295

地板清潔片 60片 清潔地板 清潔劑(60片)
售價：$188（原價 $376）
連結：https://pxbox.es.pxmart.com.tw/product/559723
imgURL:https://th.bing.com/th/id/OIP.7GFDHyqrFvzXo7Xw8_PiegHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【優品】小蘇打廚房重油垢清潔劑(400ml)
售價：$69（原價 $99）
連結：https://pxbox.es.pxmart.com.tw/product/18175
imgURL:https://th.bing.com/th/id/OIP.HbzX8Ij8oCD5kzL8ExL5LwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【CEETOON】免浸泡強力去污除垢浴室清潔劑/水垢清洗劑 2入組(500ml)
首購價：$349（原價 $799）
連結：https://pxbox.es.pxmart.com.tw/product/166762
imgURL:https://th.bing.com/th/id/OIP.n254JXuh1NaV6F8sejda6QHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【優思居】免手洗噴霧噴水玻璃清潔器(1入)
售價：$376（原價 $700）
連結：https://pxbox.es.pxmart.com.tw/product/210072
imgURL:https://th.bing.com/th/id/OIP.0MUr986Yhjf6Z-CegO6uGAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Castle 家適多】廚衛清潔超值組(4入清潔噴霧組)
首購價：$2,080（原價 $2,280）
連結：https://pxbox.es.pxmart.com.tw/product/260154
imgURL:https://th.bing.com/th/id/OIP._Ylz0ESTkGpYVCHIbaeeZgHaHa?w=217&h=217&c=7&r=0&o=7&pid=1.7&rm=3

【百鈴】髒會滅免用清潔劑去油便利布-30入(1組)
首購價：$384（原價 $1,200）
連結：https://pxbox.es.pxmart.com.tw/product/264946
imgURL:https://th.bing.com/th/id/OIP.Cv2m57DMYEkWeO24pl-GQgHaHa?w=180&h=180&c=7&o=7&pid=1.7&rm=3&retry=2

【HouseKeeper 妙管家】瞬乾地板清潔劑(2000g)
售價：$99（原價 $149）
連結：https://pxbox.es.pxmart.com.tw/product/18290
imgURL:https://th.bing.com/th/id/OIP.k9cnFDg-S3Ij5Oo-l0xO2QHaHa?w=183&h=183&c=7&o=7&pid=1.7&rm=3&retry=2

【HouseKeeper 妙管家】洗衣槽專用清潔劑(150g×4袋/盒)
售價：$89（原價 $109）
連結：https://pxbox.es.pxmart.com.tw/product/5301
imgURL:https://th.bing.com/th/id/OIP.1Nf0x_wphm_pPXfWyP2JIwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【CEETOON】多功能魔術萬用清潔去污膏500g_贈海綿刷(3入組)
首購價：$412（原價 $1,190）
連結：https://pxbox.es.pxmart.com.tw/product/40132
imgURL:https://th.bing.com/th/id/OIP.ZRwhZmE2doJQU0KrfHOUSAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【白博士】廚房清潔劑泡沫式(600ml)
售價：$68（原價 $68）
連結：https://pxbox.es.pxmart.com.tw/product/10677
imgURL:https://th.bing.com/th/id/OIP.wqyO7QZj6-kBcdmIQY6qEwAAAA?w=124&h=194&c=7&r=0&o=7&pid=1.7&rm=3

【HouseKeeper 妙管家】浴廁清潔劑(720g×2瓶)
售價：$59（原價 $75）
連結：https://pxbox.es.pxmart.com.tw/product/10753
imgURL:https://th.bing.com/th/id/OIP.0uTos4-MR2JYv1TnUxuCawHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Cif 晶杰】專家系列清潔劑-瞬效除黴(435ml)
售價：$149（原價 $159）
連結：https://pxbox.es.pxmart.com.tw/product/554761
imgURL:https://th.bing.com/th/id/OIP.79yGM9bwsdBRkpszFd2PAQHaHa?w=202&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【蒲公英】環保萬用清潔劑(500g)
售價：$75（原價 $160）
連結：https://pxbox.es.pxmart.com.tw/product/25908

大公雞 萬能清潔劑 CHANTE CLAIR 多功能油污淨廚房除油劑(600ml×2瓶)
首購價：$420（原價 $858）
連結：https://pxbox.es.pxmart.com.tw/product/578622
imgURL:https://th.bing.com/th/id/OIP.qZ6GwBrxpDkgG0bTlD_DxAHaEK?w=293&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【潔霜】S浴廁清潔劑潔淨杏香(1050g)
售價：$59（原價 $59）
連結：https://pxbox.es.pxmart.com.tw/product/6084
imgURL:https://th.bing.com/th/id/OIP.7TWrYVYC2BLFqg1-Zrg-owHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【百鈴】髒會滅銅纖維抑菌去汙免洗劑擦巾L號10入(1組)
首購價：$336（原價 $2,100）
連結：https://pxbox.es.pxmart.com.tw/product/264875
imgURL:https://th.bing.com/th/id/OIP.pvh_bV6YJpJEiMhCseu-kAHaHa?w=190&h=190&c=7&r=0&o=7&pid=1.7&rm=3

【Castle 家適多】廚房全效萬用清潔劑 500ml(3入)
首購價：$1,490（原價 $1,690）
連結：https://pxbox.es.pxmart.com.tw/product/260178
imgURL:https://th.bing.com/th/id/OIP._Ylz0ESTkGpYVCHIbaeeZgHaHa?w=138&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【HouseKeeper 妙管家】木質地板清潔劑(1000g)
售價：$95（原價 $109）
連結：https://pxbox.es.pxmart.com.tw/product/25046
imgURL:https://th.bing.com/th/id/OIP.k9cnFDg-S3Ij5Oo-l0xO2QHaHa?w=183&h=183&c=7&r=0&o=7&pid=1.7&rm=3

【MARNA】萬用家事清潔3件組(窗軌清潔刷+浴室刮刀+廚房刮板)
首購價：$910（原價 $1,340）
連結：https://pxbox.es.pxmart.com.tw/product/359535
imgURL:https://th.bing.com/th/id/OIP.n8_aoPViYgReC_jjHn0l9AHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【clorox 高樂氏】萬用去污清潔劑(946ml)
首購價：$104（原價 $179）
連結：https://pxbox.es.pxmart.com.tw/product/150037
imgURL:https://th.bing.com/th/id/OIP.sRU9MGhsYy48I7ntsyRhowHaHa?w=215&h=215&c=7&r=0&o=7&pid=1.7&rm=3

【Domestos】多功能除菌清潔劑 500ml×24瓶
首購價：$1,432（原價 $1,704，箱購）
連結：https://pxbox.es.pxmart.com.tw/product/117948
imgURL:https://th.bing.com/th/id/OIP.2pqg-jZTpitHcY1Ly6rx1QHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【魔術靈】浴室清潔劑-檸檬香經濟瓶(500ml×2入)
售價：$99（原價 $99）
連結：https://pxbox.es.pxmart.com.tw/product/29161
imgURL:https://th.bing.com/th/id/OIP.zgVutHkq0VgyJdSViOwCkwHaHa?w=212&h=212&c=7&r=0&o=7&pid=1.7&rm=3

🌾 一般白米／一等米類
【天生好米】富里一等米
首購價 $160（原價 $305）
https://pxbox.es.pxmart.com.tw/search/result?keyword=米
imgURL:https://th.bing.com/th/id/OIP.GBzebbwlYp7QmufG3bKc4gHaHa?w=190&h=190&c=7&r=0&o=5&pid=1.7

【天生好米】富里一等米(2.5kg)
首購價 $153（原價 $279）
https://pxbox.es.pxmart.com.tw/product/120001
imgURL:https://th.bing.com/th/id/OIP.-DIxlGLDx8Jy9k-t0G3TkgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】富里一等米 2.5kg×6包
首購價 $988（原價 $1,674）箱購
https://pxbox.es.pxmart.com.tw/product/120002
imgURL:https://th.bing.com/th/id/OIP.tk7MEXXZ--HoK9rUkAV28AHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】山田一等米(5kg)
首購價 $265（原價 $499）
https://pxbox.es.pxmart.com.tw/product/120003
imgURL:https://th.bing.com/th/id/OIP.-PCTQWPX5bVqqClQwm43DAHaHa?w=220&h=220&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】月之米(9kg)
首購價 $492（原價 $692）
https://pxbox.es.pxmart.com.tw/product/120004
imgURL:https://th.bing.com/th/id/OIP.-PCTQWPX5bVqqClQwm43DAHaHa?w=162&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】花蓮一等糙米(3kg)
首購價 $160（原價 $305）
https://pxbox.es.pxmart.com.tw/product/120005
imgURL:https://th.bing.com/th/id/OIP.-PCTQWPX5bVqqClQwm43DAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】履歷一等月之米(2.2kg)
首購價 $146（原價 $299）
https://pxbox.es.pxmart.com.tw/product/120006
imgURL:https://th.bing.com/th/id/OIP.oGI5buWQfSpKMuJO5yJaxwHaHa?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】履歷鷺巡一等白米(2.2kg/CNS一等米)
首購價 $146（原價 $299）
https://pxbox.es.pxmart.com.tw/product/120007
imgURL:https://th.bing.com/th/id/OIP.-NXYY2h5EJWRO7aBbtkIoQHaHa?w=176&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】履歷鷺巡芋香米
首購價 $146（原價 $299）
https://pxbox.es.pxmart.com.tw/product/120008
imgURL:https://th.bing.com/th/id/OIP.M598np9WxVb3V155KD1mEAHaHa?w=201&h=201&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】花東生態台梗九號米(1.5kg/CNS二等米)
首購價 $111（原價 $298）
https://pxbox.es.pxmart.com.tw/product/120009
imgURL:https://th.bing.com/th/id/OIP.-rb-k9ziuMcBRbxcUp6B2wHaHa?w=200&h=200&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】山田芋香米(4kg/CNS二等米)
首購價 $230（原價 $499）
https://pxbox.es.pxmart.com.tw/product/120010
imgURL:https://th.bing.com/th/id/OIP.5nLuroz3oHR0x3ntGKZTMgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】產銷履歷花東生態糙米(1.5kg/CNS一等)
首購價 $111（原價 $298）
https://pxbox.es.pxmart.com.tw/product/120011
imgURL:https://th.bing.com/th/id/OIP.0kaxrtXuTh_qJPyRusT96wHaHa?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】履歷一等月之米 2.2kg×6包
首購價 $928（原價 $1,794）箱購
https://pxbox.es.pxmart.com.tw/product/120012
imgURL:https://th.bing.com/th/id/OIP.uhkOJzWChX_d3ED0DthD0wHaHa?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【天生好米】花蓮一等糙米 3kg×8包
首購價 $1,899（原價 $2,440）箱購
https://pxbox.es.pxmart.com.tw/product/120013
imgURL:https://th.bing.com/th/id/OIP.YwTAcIMFJQWiDzE-SY3Z_AAAAA?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】關山米(5kg/CNS二等米)
首購價 $237（原價 $359）
https://pxbox.es.pxmart.com.tw/product/130001
imgURL:https://th.bing.com/th/id/OIP.kinDxd0hf2Ceo2idjWC4AgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】外銷日本珍饌米(2.5kg)
首購價 $125（原價 $299）
https://pxbox.es.pxmart.com.tw/product/130002
imgURL:https://th.bing.com/th/id/OIP.srnfWVTUmD45wE9wgOu8rgHaHa?w=152&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】花蓮新米(6kg)
首購價 $251（原價 $359）
https://pxbox.es.pxmart.com.tw/product/130003
imgURL:https://th.bing.com/th/id/OIP.wBpk4kh967ogQEFnRPcKVgHaHa?w=176&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】鮮長米(12kg)
首購價 $398（原價 $569）
https://pxbox.es.pxmart.com.tw/product/130004
imgURL:https://th.bing.com/th/id/OIP.1xg20Wd_4OceiktPevG-8AHaHa?w=183&h=183&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】台梗壽司一等米(2.7kg)
首購價 $132（原價 $199）
https://pxbox.es.pxmart.com.tw/product/130005
imgURL:https://th.bing.com/th/id/OIP.CMa6hmuctFbhrPHjpGi5rgHaHa?w=161&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】正斗米(6.9kg)
首購價 $251（原價 $359）
https://pxbox.es.pxmart.com.tw/product/130006
imgURL:https://th.bing.com/th/id/OIP.8H31H28tpAE_LbRAgCLC5wHaHa?w=170&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】台灣越光米(1.5kg)
首購價 $132（原價 $249）
https://pxbox.es.pxmart.com.tw/product/130007
imgURL:https://th.bing.com/th/id/OIP.PoChqPoH_flsRWNipw_-8wHaHa?w=192&h=192&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】履歷台南11號米(6kg/CNS一等米)
首購價 $251（原價 $379）
https://pxbox.es.pxmart.com.tw/product/130008
imgURL:https://th.bing.com/th/id/OIP.LTtfSS_ct74e6h738IsegAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】米食堂長鮮米(4kg)
首購價 $148（原價 $219）
https://pxbox.es.pxmart.com.tw/product/130009
imgURL:https://th.bing.com/th/id/OIP.1xg20Wd_4OceiktPevG-8AHaHa?w=164&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】契約栽培芋香米(2.5kg)
首購價 $146（原價 $251）
https://pxbox.es.pxmart.com.tw/product/130010
imgURL:https://th.bing.com/th/id/OIP.2jKlCLeKR4N4Kg60jYlQMwHaHW?w=204&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】花蓮香米(6kg)
售價 $300（原價 $499）
https://pxbox.es.pxmart.com.tw/product/130011
imgURL:https://th.bing.com/th/id/OIP.lkgV6yCSgR_STqJY2UYSXgHaHa?w=158&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】壽司米(3kg/CNS二等米)
首購價 $132（原價 $199）
https://pxbox.es.pxmart.com.tw/product/130012
imgURL:https://th.bing.com/th/id/OIP.kinDxd0hf2Ceo2idjWC4AgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】15℃特級米(3.4kg)
首購價 $139（原價 $198）
https://pxbox.es.pxmart.com.tw/product/130013
imgURL:https://th.bing.com/th/id/OIP.3JwQB9jIFaVATyPdxcqO1AHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】豐田的金穗/一等米(1.5kg)
售價 $90（原價 $239）
https://pxbox.es.pxmart.com.tw/product/130014
imgURL:https://th.bing.com/th/id/OIP.HCAJjJsj_AcVpVVuaD1f8QHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】台灣霧峰芋香米(1.8kg/一等米)
首購價 $111（原價 $279）
https://pxbox.es.pxmart.com.tw/product/130015
imgURL:https://th.bing.com/th/id/OIP.ZMqPjaV72WmVdZVlC60d5wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】履歷一等特級台梗米(2.2kg)
首購價 $125（原價 $239）
https://pxbox.es.pxmart.com.tw/product/130016
imgURL:https://th.bing.com/th/id/OIP.CMa6hmuctFbhrPHjpGi5rgHaHa?w=183&h=183&c=7&r=0&o=7&pid=1.7&rm=3

【三好米】花東米(1.5kg/二等米)
售價 $145（原價 $159）
https://pxbox.es.pxmart.com.tw/product/130017
imgURL:https://th.bing.com/th/id/OIP.ZMqPjaV72WmVdZVlC60d5wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

🌾 樂米穀場系列
【樂米穀場】花蓮富里產-初雪美姬米(一等米) 1.5kg×6包
首購價 $699（原價 $1,392）箱購
https://pxbox.es.pxmart.com.tw/product/140001
imgURL:https://th.bing.com/th/id/OIP.HCAJjJsj_AcVpVVuaD1f8QHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】花蓮富里產初雪美姬(1.5kg/一等米)
首購價 $118（原價 $232）
https://pxbox.es.pxmart.com.tw/product/140002
imgURL:https://th.bing.com/th/id/OIP.HCAJjJsj_AcVpVVuaD1f8QHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】台東關山好米(9kg)
首購價 $412（原價 $589）
https://pxbox.es.pxmart.com.tw/product/140003
imgURL:https://th.bing.com/th/id/OIP.U5tEKOR-E4EqwP3YyDW6WQHaHa?w=161&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】池上壹等香米 一等米(6kg)
首購價 $328（原價 $499）
https://pxbox.es.pxmart.com.tw/product/140004
imgURL:https://th.bing.com/th/id/OIP.3LbHvpemA8sQc95zzzs2lgHaHa?w=162&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】花蓮富里產有機栽培雪姬之星(一等米) 1.5kg×6包
首購價 $799（原價 $1,392）箱購
https://pxbox.es.pxmart.com.tw/product/140005
imgURL:https://th.bing.com/th/id/OIP.HCAJjJsj_AcVpVVuaD1f8QHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】台東縣關山鎮農會關山香米(一等米) 1.5kg×12包
首購價 $1,299（原價 $2,148）箱購
https://pxbox.es.pxmart.com.tw/product/140006
imgURL:https://th.bing.com/th/id/OIP.bqhovwTBh7VXZqFJd_2G1AHaHa?w=161&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】臺東池上一等特賞米(6kg)
首購價 $328（原價 $499）
https://pxbox.es.pxmart.com.tw/product/140007
imgURL:https://th.bing.com/th/id/OIP.3LbHvpemA8sQc95zzzs2lgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】花蓮富里產有機栽培雪姬之星(1.5kg/一等米)
首購價 $118（原價 $232）
https://pxbox.es.pxmart.com.tw/product/140008
imgURL:https://th.bing.com/th/id/OIP.GvYcqovu7nuqs9iVAmrFHwHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】初雪美姬牛奶糙米(1.5kg)
首購價 $118（原價 $232）
https://pxbox.es.pxmart.com.tw/product/140009
imgURL:https://th.bing.com/th/id/OIP.8rV9_iFSWIbhZCNvE-pdcQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】台東關山產極台灣越光米(1.5kg/一等米)
首購價 $132（原價 $259）
https://pxbox.es.pxmart.com.tw/product/140010
imgURL:https://th.bing.com/th/id/OIP.DnKCDB7Jkcj3XZSmigfG4wHaHa?w=169&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】台東關山鎮農會稻香鮮米(2.5kg)
首購價 $160（原價 $249）
https://pxbox.es.pxmart.com.tw/product/140011
imgURL:https://th.bing.com/th/id/OIP.rnjiIwC-J1dDgfew1b32jwHaHa?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】台東關山產金賞御用米(1.5kg)
售價 $149（原價 $219）
https://pxbox.es.pxmart.com.tw/product/140012
imgURL:https://th.bing.com/th/id/OIP.5SRdwFoUGEpa8VR_mdoJ8wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】日本新潟縣產彩虹之光耀(一等米) 1kg×6包
首購價 $899（原價 $1,494）箱購
https://pxbox.es.pxmart.com.tw/product/140013
imgURL:https://th.bing.com/th/id/OIP.sl_hDrINMlTy3c4UD5ts8AHaHa?w=178&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【樂米穀場】日本北海道產夢美人(1.5kg)
首購價 $279（原價 $399）
https://pxbox.es.pxmart.com.tw/product/140014
imgURL:https://th.bing.com/th/id/OIP.HCAJjJsj_AcVpVVuaD1f8QHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

🌾 大倉米鋪系列
【大倉米鋪】牛奶公主米(一等米) 1.5kg×6包
首購價 $669（原價 $1,314）箱購
https://pxbox.es.pxmart.com.tw/product/150001
imgURL:https://th.bing.com/th/id/OIP.mkbkx0rGMxe7Zt7-qGp0GQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】少女之心的米(一等米) 1.5kg×12包
首購價 $1,479（原價 $2,388）箱購
https://pxbox.es.pxmart.com.tw/product/150002
imgURL:https://th.bing.com/th/id/OIP.gqxrhYw3kqeOo_3v63qDCgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】台灣越光米(一等米) 1.5kg×12包
首購價 $1,408（原價 $2,148）箱購
https://pxbox.es.pxmart.com.tw/product/150003
imgURL:https://th.bing.com/th/id/OIP.PoChqPoH_flsRWNipw_-8wHaHa?w=192&h=192&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】少女之心的米(1.5kg/一等米)
首購價 $118（原價 $199）
https://pxbox.es.pxmart.com.tw/product/150004
imgURL:https://th.bing.com/th/id/OIP.gqxrhYw3kqeOo_3v63qDCgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】台灣越光米(1.5kg/一等米)
首購價 $118（原價 $179）
https://pxbox.es.pxmart.com.tw/product/150005
imgURL:https://th.bing.com/th/id/OIP.iO_OOtCoUbhRHi8udnnt4AHaHa?w=192&h=192&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】上野關山香米(1.5kg/一等米)
首購價 $118（原價 $229）
https://pxbox.es.pxmart.com.tw/product/150006
imgURL:https://th.bing.com/th/id/OIP.KSX0bAybBkTWL-VXqRI5IgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】池農無毒栽培米(一等米) 1.5kg×12包
首購價 $1,479（原價 $2,148）箱購
https://pxbox.es.pxmart.com.tw/product/150007
imgURL:https://th.bing.com/th/id/OIP.mkbkx0rGMxe7Zt7-qGp0GQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【大倉米鋪】關山雷公米(一等米) 1.5kg×8包
首購價 $919（原價 $1,832）箱購
https://pxbox.es.pxmart.com.tw/product/150008
imgURL:https://th.bing.com/th/id/OIP.ZkgraxNMQne0tEPKRH0wCwHaHa?w=210&h=210&c=7&r=0&o=7&pid=1.7&rm=3

🌾 中興米／其他品牌
【中興米】優健長米(4kg)
首購價 $148（原價 $228）
https://pxbox.es.pxmart.com.tw/product/160001
imgURL:https://th.bing.com/th/id/OIP.V3YnD4BzsRs--1OHx2QCJgHaE4?w=283&h=187&c=7&r=0&o=7&pid=1.7&rm=3

【中興米】外銷日本米(2.5kg/一等米)
首購價 $118（原價 $268）
https://pxbox.es.pxmart.com.tw/product/160002
imgURL:https://th.bing.com/th/id/OIP.MX74QdiDpS-N1weRg7VZUgHaHa?w=204&h=204&c=7&r=0&o=7&pid=1.7&rm=3

🥚 生鮮雞蛋／蛋液類
【上豐蛋品】小農蛋(30顆)
首購價 $322（原價 $525）
https://pxbox.es.pxmart.com.tw/product/439625
imgURL:https://th.bing.com/th/id/OIP.Q3WfIha_n8wMs93tw__wrgHaHa?w=178&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【初品果】富立牧場靈芝機能雞蛋(彩色蛋60顆×1組)
首購價 $799（原價 $2,100）
https://pxbox.es.pxmart.com.tw/product/515905
imgURL:https://th.bing.com/th/id/OIP.iKovwa7D3Kaq6xmTfQinVAAAAA?w=141&h=150&c=7&r=0&o=7&pid=1.7&rm=3

【初品果】富立牧場靈芝機能雞蛋(彩色蛋90顆×1組)
首購價 $1,199（原價 $4,200）
https://pxbox.es.pxmart.com.tw/product/515915
imgURL:https://th.bing.com/th/id/OIP.iKovwa7D3Kaq6xmTfQinVAAAAA?w=148&h=150&c=7&r=0&o=7&pid=1.7&rm=3

【初品果】富立牧場靈芝機能雞蛋(紅蛋90顆×1組)
首購價 $1,099（原價 $2,700）
https://pxbox.es.pxmart.com.tw/product/515895
imgURL:https://th.bing.com/th/id/OIP.iKovwa7D3Kaq6xmTfQinVAAAAA?w=141&h=150&c=7&r=0&o=7&pid=1.7&rm=3

【上豐蛋品】冷藏新鮮蛋黃液(1箱4罐，每罐970g)
首購價 $890（原價 $1,472）
https://pxbox.es.pxmart.com.tw/product/495322
imgURL:https://th.bing.com/th/id/OIP.80VDStXIzcWl0dwn0nlXKAHaHa?w=158&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【上豐蛋品】冷藏新鮮蛋白液(1箱4罐，每罐970g)
首購價 $650（原價 $1,088）
https://pxbox.es.pxmart.com.tw/product/441982
imgURL:https://th.bing.com/th/id/OIP.80VDStXIzcWl0dwn0nlXKAHaHa?w=158&h=180&c=7&r=0&o=7&pid=1.7&rm=3

🍳 蛋料理／即食類
【泰凱食堂】冰火山溏心蛋(4袋，每袋5入)
首購價 $397（原價 $758）
https://pxbox.es.pxmart.com.tw/product/55236
imgURL:https://th.bing.com/th/id/OIP.YC3j-jEKNfw41U6LeSb0kAHaF7?w=243&h=194&c=7&r=0&o=7&pid=1.7&rm=3

【泰凱食堂】冰火山溏心蛋(8袋，每袋5入)
首購價 $725（原價 $1,520）
https://pxbox.es.pxmart.com.tw/product/55237
imgURL:https://th.bing.com/th/id/OIP.YAoJh4Wf2FhzhlXzvTzInwHaHa?w=200&h=200&c=7&r=0&o=7&pid=1.7&rm=3

【泰凱食堂】冰火山溏心蛋(12袋，每袋5入)
首購價 $1,125（原價 $2,330）
https://pxbox.es.pxmart.com.tw/product/55238
imgURL:https://th.bing.com/th/id/OIP.r69cKh6oqwySSJ65PHUDHwHaHa?w=187&h=187&c=7&r=0&o=7&pid=1.7&rm=3

【泰凱食堂】冰火山溏心蛋(24袋，每袋5入)
首購價 $2,199（原價 $4,675）
https://pxbox.es.pxmart.com.tw/product/55239
imgURL:https://th.bing.com/th/id/OIP.vv3UKBAKAWsNNbr55JC1ywHaH_?w=185&h=200&c=7&r=0&o=7&pid=1.7&rm=3

【台灣蘇伯湯】綜合蛋花湯5種口味/盒(3盒1組)
首購價 $251（原價 $450）
https://pxbox.es.pxmart.com.tw/product/174112
imgURL:https://th.bing.com/th/id/OIP.2Ifils1_mq2KHYnijmSv9QHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【光泉】雞蛋豆奶(330ml×6入)
售價 $89（原價 $96）
https://pxbox.es.pxmart.com.tw/product/87526
imgURL:https://th.bing.com/th/id/OIP.x5BV4wDDWFjeKPBuN8L80wHaEK?w=292&h=180&c=7&r=0&o=7&pid=1.7&rm=3

🍜 雞蛋麵／零食點心類
【好勁道】月見雞蛋麵(300g)
售價 $24
https://pxbox.es.pxmart.com.tw/product/21764
imgURL:https://th.bing.com/th/id/OIP.Ba2mfvAcpdBejSdGUOrErQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【五木】雞蛋麵(300g)
售價 $24
https://pxbox.es.pxmart.com.tw/product/25943
imgURL:https://th.bing.com/th/id/OIP.L2sva-EJZX1iitd7Y5meQQHaJ4?w=140&h=186&c=7&r=0&o=7&pid=1.7&rm=3

【五木】經濟包雞蛋麵(2000g)
售價 $159
https://pxbox.es.pxmart.com.tw/product/4519
imgURL:https://th.bing.com/th/id/OIP.eFFyvqgF2r4d78iS853k7gHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【新宏】雞蛋麵(600g)
售價 $69
https://pxbox.es.pxmart.com.tw/product/350774
imgURL:https://th.bing.com/th/id/OIP.SFpazbWwGc9eXmDFwkx5hgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【龍口】天下雞蛋麵(1.8kg/包)
售價 $155
https://pxbox.es.pxmart.com.tw/product/170233
imgURL:https://th.bing.com/th/id/OIP.RoyLCs28ugXUS0KQeT85_gHaHa?w=166&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【鄉傳】勁Q雞蛋關廟麵(966g)
售價 $75（原價 $149）
https://pxbox.es.pxmart.com.tw/product/120364
imgURL:https://th.bing.com/th/id/OIP.bhurH4bMXzv0C79QbCi22wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Soos Teszta】雞蛋寬帶麵(200g)
售價 $79（原價 $99）
https://pxbox.es.pxmart.com.tw/product/553099
imgURL:https://th.bing.com/th/id/OIP.u1-KDukuqulkgL-dzdFbAgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Soos Teszta】雞蛋義大利麵200g(多款型態)
售價 $75（原價 $99）
https://pxbox.es.pxmart.com.tw/product/553097
imgURL:https://th.bing.com/th/id/OIP.u1-KDukuqulkgL-dzdFbAgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【Soos Teszta】雞蛋義大利麵400g(直麵)
售價 $129（原價 $159）
https://pxbox.es.pxmart.com.tw/product/553093
imgURL:https://th.bing.com/th/id/OIP.u1-KDukuqulkgL-dzdFbAgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【卡賀】雞蛋沙琪瑪(750g)
首購價 $102（原價 $159）
https://pxbox.es.pxmart.com.tw/product/68668
imgURL:https://th.bing.com/th/id/OIP.79Enq7h46LknJg_D9XyGMwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【卡賀】手提雞蛋沙琪瑪(560g)
售價 $93
https://pxbox.es.pxmart.com.tw/product/4929
imgURL:https://th.bing.com/th/id/OIP.79Enq7h46LknJg_D9XyGMwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【卡賀】雞蛋沙琪瑪(180g)
售價 $39（原價 $45）
https://pxbox.es.pxmart.com.tw/product/24910
imgURL:https://th.bing.com/th/id/OIP.1cUMPtq0Ld_fJF4BnCd8BgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【小林煎餅】小林雞蛋煎餅(200g)
售價 $120
https://pxbox.es.pxmart.com.tw/product/539913
imgURL:https://th.bing.com/th/id/OIP.8wZReiortWeBmoAvpryKWQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【老楊】雞蛋方塊酥(210g)
售價 $35（原價 $37）
https://pxbox.es.pxmart.com.tw/product/636704
imgURL:https://th.bing.com/th/id/OIP.fI5QaJTIGArwrV4AJy4BHgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【九福】雞蛋酥(200g)
售價 $55
https://pxbox.es.pxmart.com.tw/product/21761
imgURL:https://th.bing.com/th/id/OIP.5E4CYz4TAZDHj_OZWm_FsgHaKe?w=143&h=202&c=7&r=0&o=7&pid=1.7&rm=3

【義美】薄脆蛋捲-經典原味(120g)
售價 $62
https://pxbox.es.pxmart.com.tw/product/3456
imgURL:https://th.bing.com/th/id/OIP.9UOEecuD5Y1-iCvVSypDMQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

📦 雞蛋收納盒／工具類
【No Brand】EMC 10格雞蛋收納盒(25.5×12.5×7cm)
首購價 $34（原價 $69）
https://pxbox.es.pxmart.com.tw/product/159936
imgURL:https://th.bing.com/th/id/OIP.UzHcPeZdVzs0HkRkQehMwQHaHa?w=209&h=209&c=7&r=0&o=7&pid=1.7&rm=3

【MIKAHOUSE 橘之屋】雞蛋隔離保鮮盒(29.8×11.6×6.4cm)
首購價 $62（原價 $99）
https://pxbox.es.pxmart.com.tw/product/5590
imgURL:https://th.bing.com/th/id/OIP.O-N7WftSbwsDrdNmoTPqnAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【SHCJ 生活采家】可折疊三層24顆保鮮雞蛋架(2入組)
首購價 $235（原價 $630）
https://pxbox.es.pxmart.com.tw/product/138065
imgURL:https://th.bing.com/th/id/OIP.71pSmvBVRgIblzLIJs9nbQHaKX?w=155&h=217&c=7&r=0&o=7&pid=1.7&rm=3

【SHCJ 生活采家】抽屜式雙層32顆保鮮雞蛋架(2入組)
首購價 $314（原價 $860）
https://pxbox.es.pxmart.com.tw/product/138059
imgURL:https://th.bing.com/th/id/OIP.elkPYcEM2J6nbiIsTQeMwQHaL2?w=120&h=192&c=7&r=0&o=7&pid=1.7&rm=3

【日本霜山】冰箱懸掛抽屜式雞蛋收納盒-3入
首購價 $298（原價 $2,000）
https://pxbox.es.pxmart.com.tw/product/408052
imgURL:https://th.bing.com/th/id/OIP.xuMdoo-o9R3Iod6bV9I7TAHaHa?w=212&h=212&c=7&r=0&o=7&pid=1.7&rm=3

【日本霜山】可層疊冰箱雞蛋收納盒-3入
首購價 $806（原價 $2,000）
https://pxbox.es.pxmart.com.tw/product/245979
imgURL:https://th.bing.com/th/id/OIP.yl-Xkr6OtdAxHaEWtQ5fTwHaHa?w=213&h=213&c=7&r=0&o=7&pid=1.7&rm=3

【KARY】可疊放冰箱雞蛋收納盒(4入)
首購價 $330（原價 $572）
https://pxbox.es.pxmart.com.tw/product/75143
imgURL:https://th.bing.com/th/id/OIP.QTo1vzBauXmipOLp-PNl6wHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【YAMADA】日本製雞蛋分離保存容器(3入組)
首購價 $265（原價 $540）
https://pxbox.es.pxmart.com.tw/product/423158
imgURL:https://th.bing.com/th/id/OIP.HmalGv877Mf54IJif-Av6AHaNd?w=121&h=220&c=7&r=0&o=7&pid=1.7&rm=3

蛋清分離器3入
首購價 $88（原價 $252）
https://pxbox.es.pxmart.com.tw/product/573857
imgURL:https://th.bing.com/th/id/OIP.6M6jyRP-rsuDwtQjpicKgQHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【Imakara】打孔切片切瓣三合一切蛋器
首購價 $266（原價 $1,200）
https://pxbox.es.pxmart.com.tw/product/370757
imgURL:https://th.bing.com/th/id/OIP.neV3J95wei5T7xUSHdb9KAAAAA?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

🔌 煮蛋機／蒸蛋器類
【SAMPO 聲寶】煮蛋神器(KA-DA04)
售價 $990（原價 $1,490）
https://pxbox.es.pxmart.com.tw/product/675769
imgURL:https://th.bing.com/th/id/OIP.KnQYkA-Bjn7PV2G41oyVGgHaHx?w=157&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【SAMPO 聲寶】煮蛋神器-(KA-DA04)
售價 $880（原價 $1,290）
https://pxbox.es.pxmart.com.tw/product/295631
imgURL:https://th.bing.com/th/id/OIP.KnQYkA-Bjn7PV2G41oyVGgHaHx?w=157&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【EUPA 優柏】多功能迷你蒸蛋器(白色)(TSK-8990W)
首購價 $580（原價 $1,090）
https://pxbox.es.pxmart.com.tw/product/227252
imgURL:https://th.bing.com/th/id/OIP.MzJLL-4GT8BC8rjez-hOVgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【大家源】美味煮蛋機(TCY-320202)
售價 $799（原價 $1,980）
https://pxbox.es.pxmart.com.tw/product/397892
imgURL:https://th.bing.com/th/id/OIP.pt8_qyAWJLliIg14xfLw9AHaHa?w=196&h=196&c=7&r=0&o=7&pid=1.7&rm=3

【諾曼百赫】德國ROMMELSBACHER多功能煮蛋器/蒸蛋機(ER 600)
首購價 $1,290（原價 $1,990）
https://pxbox.es.pxmart.com.tw/product/325425
imgURL:https://th.bing.com/th/id/OIP.bspCw0K2nkXMdEFV3TZv8QHaHa?w=205&h=205&c=7&r=0&o=7&pid=1.7&rm=3

【諾曼百赫】多功能煮蛋器/可煮6顆蛋(ER-600)
首購價 $1,550（原價 $2,480）
https://pxbox.es.pxmart.com.tw/product/220767
imgURL:https://th.bing.com/th/id/OIP.bspCw0K2nkXMdEFV3TZv8QHaHa?w=145&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【THOMSON 湯姆盛】蛋蛋神氣機TM-SAK56
首購價 $1,090（原價 $1,680）
https://pxbox.es.pxmart.com.tw/product/385114
imgURL:https://th.bing.com/th/id/OIP.w0nBlu3SG79FcMCd7XUxcwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【TWLADY】多功能蒸煮蛋器/可煮4顆蛋(TW1022)
首購價 $499（原價 $1,480）
https://pxbox.es.pxmart.com.tw/product/246122
imgURL:https://th.bing.com/th/id/OIP.N6hTdb9HEJX7DW1KwS7n9gHaHa?w=161&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【COLACO】304不銹鋼蒸蛋碗鍋-大號(1入組)
首購價 $139（原價 $398）
https://pxbox.es.pxmart.com.tw/product/573753
imgURL:https://th.bing.com/th/id/OIP.C41dji1nuEvkQb0QBq69ZgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【COLACO】304不銹鋼蒸蛋碗鍋-小號(1入組)
首購價 $125（原價 $378）
https://pxbox.es.pxmart.com.tw/product/573751
imgURL:https://th.bing.com/th/id/OIP.C41dji1nuEvkQb0QBq69ZgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

其他
【藍帶無穀濃縮】2包超值組 全齡貓(360g 鮮雞蛋+膠原蔬果)
首購價 $262（原價 $440）
https://pxbox.es.pxmart.com.tw/product/137454
imgURL:https://th.bing.com/th/id/OIP.R-yda-BZVVJ-PA9tC5GBHAHaHa?w=215&h=215&c=7&r=0&o=7&pid=1.7&rm=3

【ELEMIS】大溪地雞蛋花身體磨砂霜490g(航空版)
首購價 $1,000（原價 $2,250）
https://pxbox.es.pxmart.com.tw/product/671403
imgURL:https://th.bing.com/th/id/OIP.imlMti6MSm1LdGrJNEIwrAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

🍜 台灣品牌袋麵／碗麵類
【維力】原祖雞汁麵(70g×5包)
售價 $45（原價 $48）
https://pxbox.es.pxmart.com.tw/product/4661
imgURL:https://th.bing.com/th/id/OIP.kUvzkQqfEghswJgk1QtfFgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【維力】炸醬麵(90g×5包)
售價 $75（原價 $77）
https://pxbox.es.pxmart.com.tw/product/4662
imgURL:https://th.bing.com/th/id/OIP.dvnJlHVm8N7q8OngW5FfdAHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【維力】炸醬麵桶麵(90g×3桶)
售價 $60
https://pxbox.es.pxmart.com.tw/product/4663
imgURL:https://th.bing.com/th/id/OIP.QbSmE23D2Ern2UQbhspF9gHaHa?w=186&h=186&c=7&r=0&o=7&pid=1.7&rm=3

【維力】大乾麵-地獄辣椒(100g×5包)
售價 $83
https://pxbox.es.pxmart.com.tw/product/4664
imgURL:https://th.bing.com/th/id/OIP.1ff2QPxCfhIT_vf7NHuWWwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【維力】大乾麵碗麵-紅油擔擔風味 110g×12碗
首購價 $235（原價 $336）箱購
https://pxbox.es.pxmart.com.tw/product/4665
imgURL:https://th.bing.com/th/id/OIP.K36qSSngUeRHQHbWaxIidQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【維力】炸醬麵-原味(90g×5入)×6組
首購價 $319（原價 $462）箱購
https://pxbox.es.pxmart.com.tw/product/4666
imgURL:https://th.bing.com/th/id/OIP.YdqSMYxqebD1If-W1uNuTgHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【維力】手打麵-蔥香牛肉風味(80g×5包)
售價 $68
https://pxbox.es.pxmart.com.tw/product/4667
imgURL:https://th.bing.com/th/id/OIP.3S880P6o1DjpTbpRHDU0OQHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【維力】素飄香-當歸枸杞風味麵(95g)
售價 $31
https://pxbox.es.pxmart.com.tw/product/4668
imgURL:https://th.bing.com/th/id/OIP.NZzy3L4Uil2ttRrtYwcJ4AHaGo?w=198&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【維力】素飄香-麻辣燙風味麵(100g)
售價 $31
https://pxbox.es.pxmart.com.tw/product/4669
imgURL:https://th.bing.com/th/id/OIP.hWZRNiShbLwG3DABy_89nAHaGO?w=232&h=195&c=7&r=0&o=7&pid=1.7&rm=3

【維力】素飄香袋麵-麻辣燙風味麵(90g×5入)×6袋
首購價 $273（原價 $450）箱購
https://pxbox.es.pxmart.com.tw/product/4670
imgURL:https://th.bing.com/th/id/OIP.7ChPNLQ5sqkyN1EZ-83PGQHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【維力】真爽蔥辣牛肉風味麵(75g×5入)
售價 $65（原價 $72）
https://pxbox.es.pxmart.com.tw/product/4671
imgURL:https://th.bing.com/th/id/OIP.7lMxp_e2FRJd0UxudkpgLAHaHa?w=187&h=187&c=7&r=0&o=7&pid=1.7&rm=3

【維力】媽媽麵 蛤蜊海鮮風味
售價 $59（原價 $75）
https://pxbox.es.pxmart.com.tw/product/4672
imgURL:https://th.bing.com/th/id/OIP.0GimoFfS9bKa7t50W4m7ngHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【維力】一度贊燉肉麵(200g×3包)
售價 $129（原價 $132）
https://pxbox.es.pxmart.com.tw/product/4673
imgURL:https://th.bing.com/th/id/OIP.cb7HnRDrhY6rJofumcVlxAHaHa?w=212&h=212&c=7&r=0&o=7&pid=1.7&rm=3

【維力】一度贊-皮辣椒雞肉麵(185g×3入)
售價 $132
https://pxbox.es.pxmart.com.tw/product/4674
imgURL:https://th.bing.com/th/id/OIP.BPOcDy2UENAd0DmLnsVekAHaHa?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【一度贊】碗麵-紅燒牛肉麵 200g×12碗
首購價 $357（原價 $516）箱購
https://pxbox.es.pxmart.com.tw/product/4675
imgURL:https://th.bing.com/th/id/OIP.Ey_8SI3nLHnTPvf4q3do2wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【一度贊】碗麵-爌肉麵 200g×12碗
首購價 $357（原價 $516）箱購
https://pxbox.es.pxmart.com.tw/product/4676
imgURL:https://th.bing.com/th/id/OIP.AO_cwWhxTVcs3N3an-ACtQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【統一】科學麵家庭號(15g×20入)
售價 $55
https://pxbox.es.pxmart.com.tw/product/5230
imgURL:https://th.bing.com/th/id/OIP.anLaymr7L0c3moiBAqVOHAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【統一】鮮蝦風味碗麵(83g×3碗)
售價 $56（原價 $57）
https://pxbox.es.pxmart.com.tw/product/5231
imgURL:https://th.bing.com/th/id/OIP.GCy0Yj-FdL87vYJD-bzaSQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【統一麵】袋麵-蔥燒牛肉風味(90g×5入)×6袋
首購價 $328（原價 $480）箱購
https://pxbox.es.pxmart.com.tw/product/5232
imgURL:https://th.bing.com/th/id/OIP.GPlm6_iZ8A2bUDHBJJw9tgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【味味A】排骨雞湯麵(90g×5入)×6組
首購價 $319（原價 $462）箱購
https://pxbox.es.pxmart.com.tw/product/5233
imgURL:https://down-tw.img.susercontent.com/file/tw-11134207-7r98p-lx44j3c1aw4wf1

【滿漢大餐】袋麵-蔥燒牛肉麵(187g×3入)
首購價 $375（原價 $540）箱購
https://pxbox.es.pxmart.com.tw/product/5234
imgURL:https://th.bing.com/th/id/OIP.q-00EcyiEdqF7sAEODlsHwHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【滿漢大餐】袋麵-蔥燒豬肉麵(193g×3入)×4組
首購價 $375（原價 $540）箱購
https://pxbox.es.pxmart.com.tw/product/5235
imgURL:https://th.bing.com/th/id/OIP.vXmz-GmRn5hfjG3yZPKejQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【滿漢大餐】袋麵-麻辣鍋牛肉麵(200g×3入)×4組
首購價 $375（原價 $540）箱購
https://pxbox.es.pxmart.com.tw/product/5236
imgURL:https://th.bing.com/th/id/OIP.q-00EcyiEdqF7sAEODlsHwHaHa?w=193&h=193&c=7&r=0&o=7&pid=1.7&rm=3

【味丹】味味麵(78g×5包)
售價 $68
https://pxbox.es.pxmart.com.tw/product/5237
imgURL:https://th.bing.com/th/id/OIP.vhC6mXG0h3YR91r_5ehtDwHaHa?w=180&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【味丹】隨緣袋麵-紅燒嫩菇湯(86g×5入)
售價 $79
https://pxbox.es.pxmart.com.tw/product/5238
imgURL:https://th.bing.com/th/id/OIP.AMUCbirs_FX4eR7uf4O9rQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【味丹】隨緣杯麵-椎茸之味湯 60g×12杯
首購價 $168（原價 $252）箱購
https://pxbox.es.pxmart.com.tw/product/5239
imgURL:https://th.bing.com/th/id/OIP.y4TtZG8-cU6ohIHyw6jHmwHaHa?w=201&h=201&c=7&r=0&o=7&pid=1.7&rm=3

【味丹】隨緣杯麵-麻辣燙湯麵 58g×12杯
首購價 $168（原價 $252）箱購
https://pxbox.es.pxmart.com.tw/product/5240
imgURL:https://th.bing.com/th/id/OIP.V_bj1HuMhFEomdzXzOnW-QHaHa?w=187&h=187&c=7&r=0&o=7&pid=1.7&rm=3

【味丹】美味小舖 蔥燒牛肉湯麵(72g×5包)
售價 $60
https://pxbox.es.pxmart.com.tw/product/5241
imgURL:https://th.bing.com/th/id/OIP.b0Hve3O8qAB7ig3HA9gGpAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【味丹】一品麻辣臭豆腐麵袋麵(218g×3入)
售價 $129
https://pxbox.es.pxmart.com.tw/product/5242
imgURL:https://th.bing.com/th/id/OIP.HgyvqaY8o0aQ9K6nDd417wHaHa?w=183&h=183&c=7&r=0&o=7&pid=1.7&rm=3

【五木】純麵煮意-原味(8片)
售價 $65（原價 $79）
https://pxbox.es.pxmart.com.tw/product/5243
imgURL:https://th.bing.com/th/id/OIP.zSw6K0Jo_cv3gN53ERy0pgHaEK?w=321&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【五木】蔬紅燒拉麵(325g)
售價 $71
https://pxbox.es.pxmart.com.tw/product/5244
imgURL:https://th.bing.com/th/id/OIP.WqmE476kcvQA-7NGOUzsygHaHa?w=186&h=186&c=7&r=0&o=7&pid=1.7&rm=3

🍜 台酒 TTL 系列
【TTL 台酒】花雕雞袋麵(200g×3入)
售價 $139
https://pxbox.es.pxmart.com.tw/product/6001
imgURL:https://th.bing.com/th/id/OIP.oMRvmLE2Q1LBz40uZV8lWQHaHh?w=207&h=211&c=7&r=0&o=7&pid=1.7&rm=3

【TTL 台酒】花雕雞碗麵(200g)
售價 $49
https://pxbox.es.pxmart.com.tw/product/6002
imgURL:https://th.bing.com/th/id/OIP.oMRvmLE2Q1LBz40uZV8lWQHaHh?w=195&h=199&c=7&r=0&o=7&pid=1.7&rm=3

【TTL 台酒】麻油雞袋麵(200g×3入)
售價 $139
https://pxbox.es.pxmart.com.tw/product/6003
imgURL:https://th.bing.com/th/id/OIP.6n5hwU7MvwIu3MQlgIVtqQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【TTL 台酒】紅酒燉牛肉麵(195g×3包)
首購價 $113（原價 $162）
https://pxbox.es.pxmart.com.tw/product/6004
imgURL:https://th.bing.com/th/id/OIP.fIHO9bk0SGuIaRcSrQiojAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【TTL 台酒】雕酸菜牛肉碗麵(200g)
售價 $49
https://pxbox.es.pxmart.com.tw/product/6005
imgURL:https://th.bing.com/th/id/OIP.nKNLsj3O3q6B-MubZm0CoAHaHa?w=158&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【TTL 台酒】杯常幸福 海味魚蝦大賞風味麵(60g)
售價 $28
https://pxbox.es.pxmart.com.tw/product/6006
imgURL:https://th.bing.com/th/id/OIP.vRgd3JYRVI3JS3GJ2YXmjwHaHa?w=169&h=180&c=7&r=0&o=7&pid=1.7&rm=3

【TTL 台酒】花雕雞乾麵-酒香炸醬風味 110g×4包×4袋/箱
首購價 $499（原價 $799）廠購
https://pxbox.es.pxmart.com.tw/product/6007
imgURL:https://th.bing.com/th/id/OIP.oMRvmLE2Q1LBz40uZV8lWQHaHh?w=207&h=211&c=7&r=0&o=7&pid=1.7&rm=3

🍜 杯麵類
【來一客】杯麵-鮮蝦魚板(63g×3入)×8組
首購價 $364（原價 $520）箱購
https://pxbox.es.pxmart.com.tw/product/7001
imgURL:https://th.bing.com/th/id/OIP.tzcFcpAeqAn-VS0wopq37wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【來一客】杯麵-牛肉蔬菜(65g×3入)×8組
首購價 $364（原價 $520）箱購
https://pxbox.es.pxmart.com.tw/product/7002
imgURL:https://th.bing.com/th/id/OIP.szKAdC0outEiAfvOrpMsgAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【來一客】杯麵-韓式泡菜(67g×3入)×8組
首購價 $364（原價 $520）箱購
https://pxbox.es.pxmart.com.tw/product/7003
imgURL:https://th.bing.com/th/id/OIP.bnL2HVzfu_hViLyILz7oSAHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【來一客】韓式泡菜風味杯麵(67g×3杯)
售價 $65
https://pxbox.es.pxmart.com.tw/product/7004
imgURL:https://th.bing.com/th/id/OIP.MVoTLuWjCxia9G25nG6BjQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【來一客】京燉肉骨風味杯麵(71g×3杯)
售價 $65
https://pxbox.es.pxmart.com.tw/product/7005
imgURL:https://th.bing.com/th/id/OIP.OUcb16t2k18zj8vgEPlxhwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【ACECOOK】k逸品杯麵-博多豚骨風味
售價 $26（原價 $28）
https://pxbox.es.pxmart.com.tw/product/7006
imgURL:https://th.bing.com/th/id/OIP.IeRwGE31B8re7kDP2h5SjwHaHa?w=220&h=220&c=7&r=0&o=7&pid=1.7&rm=3

【SL】多功能微波泡麵碗(附蓋)台灣製
折後價 $289（原價 $600）
https://pxbox.es.pxmart.com.tw/product/7007
imgURL:https://th.bing.com/th/id/OIP.2fA6O4IpajZZzP8JFdjDLQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【PALDO 八道】迷你食麵王 牛肉湯碗麵
售價 $49（原價 $59）
https://pxbox.es.pxmart.com.tw/product/7008
imgURL:https://th.bing.com/th/id/OIP.Grw0LMQ4CLMBs_Qwcbx2eQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

🍜 韓系拉麵類
【農心】辛拉麵(120g×4入)
首購價 $69（原價 $185）
https://pxbox.es.pxmart.com.tw/product/8001
imgURL:https://th.bing.com/th/id/OIP.EE5MJy1oqQUSohaWssgqpQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】辛拉麵超值包(120g×5入)
首購價 $118（原價 $190）
https://pxbox.es.pxmart.com.tw/product/8002
imgURL:https://th.bing.com/th/id/OIP.FjNCvupXlitRue8EGsMHZgHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】辛拉麵 120g×30包
首購價 $814（原價 $1,140）箱購
https://pxbox.es.pxmart.com.tw/product/8003
imgURL:https://th.bing.com/th/id/OIP.TPt6FfHq7KjL0EeRn7WOGQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】辛辣白菜風味拉麵超值包(120g×5入)
首購價 $118（原價 $190）
https://pxbox.es.pxmart.com.tw/product/8004
imgURL:https://th.bing.com/th/id/OIP.T_GF19KjgNb80QjWbBV6oQHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】安城湯麵(125g×4入)
首購價 $106（原價 $185）
https://pxbox.es.pxmart.com.tw/product/8005
imgURL:https://th.bing.com/th/id/OIP.JMZoiTnGklPQ8rs6rvgU5wHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】爽口海鮮味烏龍麵(120g×4入)
首購價 $106（原價 $185）
https://pxbox.es.pxmart.com.tw/product/8006
imgURL:https://th.bing.com/th/id/OIP.UVJIDMcNYRCnR9qONPoBDwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】爽口烏龍麵-海鮮味湯料超值包(120g×5入)
首購價 $118（原價 $190）
https://pxbox.es.pxmart.com.tw/product/8007
imgURL:https://th.bing.com/th/id/OIP.TOuYDlZ-HXnvEnhCyt3a-AHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】爽口烏龍麵-海鮮味湯料超值包(120g×4入)
首購價 $118（原價 $190）
https://pxbox.es.pxmart.com.tw/product/8008
imgURL:https://th.bing.com/th/id/OIP.UVJIDMcNYRCnR9qONPoBDwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】韓國醡醬風味麵(140g×4入)
首購價 $125（原價 $215）
https://pxbox.es.pxmart.com.tw/product/8009
imgURL:https://th.bing.com/th/id/OIP.1ivpNfICsKOS5OiwkTYsIwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3

【農心】炸王醡醬麵(134g×4入)
首購價 $154（原價 $269）
https://pxbox.es.pxmart.com.tw/product/8010
imgURL:https://th.bing.com/th/id/OIP.1ivpNfICsKOS5OiwkTYsIwHaHa?w=203&h=203&c=7&r=0&o=7&pid=1.7&rm=3
''';
