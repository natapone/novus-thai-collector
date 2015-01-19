Objective
=========

Improve keyword extractor engine from last year [Novus-Thai](/display/THAI/Novus-Thai) project 

What is Novus-Thai?
===================

![](https://raw.githubusercontent.com/natapone/novus-thai-collector/develop/img/Hackaton-+Novus+Thai+concept.jpg)

What can be improved?
=====================

Most of the extracted keywords are only part of word and unreadable.

|Keyword|Translation|Score|
|:------|:----------|:----|
|มือถือ|Mobile.|2.254|
|iphone5|iphone5.|2.249|
|เปิดตัว|Launched.|2.239|
|สำนักพิมพ์|Publisher|2.239|
|ครับ5|--meaning less--|2.222|
|12|12|2.203|
|ที่มา|Origin|2.191|
|20|20|2.121|
|ไอแพดมินิ|IPad Mini.|2.078|
|ยังไม่|Not yet|2.006|
|ยอมความ|Compromise|1.994|
|ipadmini|ipadmini.|1.964|
|โมโตโรล่า|Motorola.|1.929|
|ต์|meaning less -- part of word "website"|1.924|
|อัพ|Up.|1.904|
|โตโร|Toro -- part of word "Motorola"|1.902|
|14|14|1.862|
|เหรียญสหรัฐ|USD.|1.788|
|เว็บไซ|Website.|1.774|
|โมโต|Moto -- part of word "Motorola"|1.773|

How to improve?
===============

Mathematical is the key!

We build [N-gram](http://en.wikipedia.org/wiki/N-gram) [Language Model](http://en.wikipedia.org/wiki/Language_model) to assess a probability of words chain if it should be a sentence or not.

### N-gram Model

![](http://upload.wikimedia.org/math/6/4/a/64ae2fdcaefa34727c9980af8198e47e.png)

**Definition**

-   ![](http://upload.wikimedia.org/math/5/4/6/54690de4d57b1b8cf943136adf64c9ac.png) = probability of observing sentence
-   n = order of [Markov chain](http://en.wikipedia.org/wiki/Markov_property)
-    to calculate conditional probability ![](http://upload.wikimedia.org/math/2/1/f/21fd5b6d28011bd7f08f8a7a147d1972.png) 

Model implementation
====================

Thai language do not have special style to emphasis special word in sentence like upper case in name of entities (city, planet, person, corporation).

However, news editor usually put quote or double-quote to emphasis keywords of the article.

We could use that to enhance probability of keywords in model by putting START(\*) and STOP sequences on it.

\*

keyword 1

keyword 2

keyword 3

STOP

Probability of n gram that contain keyword combinations are significantly higher than normal words eg.

||
|\*|word|keyword 1|keyword 2|STOP|
|\*|word|word|keyword 1|STOP|
|\*|keyword 3|word|word|STOP|

Example Thai headline news split

<table>
<col width="50%" />
<col width="50%" />
<thead>
<tr class="header">
<th align="left">Headline</th>
<th align="left">Sentences</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">&quot;สุเทพ&quot; พามวลชนหน้าศูนย์เยาวชนไทย-ญี่ปุ่นกลับราชดำเนิน</td>
<td align="left"><ul>
<li>*,สุ,เทพ,STOP</li>
<li>*,พาม,ว,ล,ชน,หน้า,ศูนย์,เยาวชน,ไทย,ญี่ปุ่น,กลับ,ราช,ดำเนิน,STOP</li>
</ul></td>
</tr>
<tr class="even">
<td align="left">'มอยส์' ลุ้นปาฏิหาริย์ 'อาร์วีพี-คาร์ริก' หายเดี้ยง</td>
<td align="left"><ul>
<li>*,มอ,ย,ส,-์,STOP</li>
<li>*,ลุ้น,ปาฏิหาริย์,STOP</li>
<li>*,อาร์,วี,พี,คา,ร,-์,ริก,STOP</li>
<li>*,หาย,เดี้ย,ง,STOP</li>
</ul></td>
</tr>
</tbody>
</table>

Result
======

Compare keywords from 25 Dec 2012 with previous engine

|Keyword|Translation|Score|Previous result|
|:------|:----------|:----|:--------------|
|ซิงค์|sync|31.898|มือถือ|
|เว็บไซต์|website|30.441|iphone5|
|แอนดรอยด์|android|29.405|เปิดตัว|
|คริสมาสต์|Christmas|25.932|สำนักพิมพ์|
|กสทช.|Office of The National Broadcasting|22.101|ครับ5|
|**โมโตโรล่า**|Motorola|21.326|12|
|วินโดวส์|Windows|20.742|ที่มา|
|อินเทอร์|inter|20.726|20|
|vlc|VLC (application)|20.033|ไอแพดมินิ|
|พอร์|Part of Form|19.908|ยังไม่|
|เว็บ|Part of website|18.692|ยอมความ|
|บไซต์|Part of website|18.455|ipadmini|
|ตี้|Part of mobility|18.303|**โมโตโรล่า**|
|เน็ต|net|18.032|ต์|
|บิ๊ก|big|17.484|อัพ|
|อร์|Part of Form|16.051|โตโร|
|นวัตกรรม|Innovation|14.416|14|
|ฟ็อก|Fox|13.843|เหรียญสหรัฐ|
|อัพ|up|13.459|เว็บไซ|
|ผู้ประกอบการ|entrepreneur|13.217|โมโต|

 

 

 
