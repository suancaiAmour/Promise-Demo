//
//  Coroutine.s
//  协程 Demo
//
//  Created by 张鸿 on 2017/11/27.
//  Copyright © 2017年 酸菜Amour. All rights reserved.
//

.text
.align 4
.globl _getSP
.globl _getFP

_getSP:
    mov   x0, sp
    ret

_getFP:
    mov   x0, x29
    ret
