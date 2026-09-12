((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var A,C,E,B={
cAY(d){var x,w="[/size][/b]\n",v=A.ba("\\r\\n?",!0,!1,!1),u=A.a1M(A.a1M(A.bQ(d,v,"\n"),A.ba("<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",!1,!0,!1),new B.c_2(),null),A.ba("<span\\b[^>]*style=[\"']([^\"']+)[\"'][^>]*>(.*?)</span>",!1,!0,!1),new B.c_3(),null)
v=A.ba("<\\s*(strong|b)\\s*>",!1,!1,!1)
v=A.bQ(u,v,"[b]")
x=A.ba("<\\s*/\\s*(strong|b)\\s*>",!1,!1,!1)
v=A.bQ(v,x,"[/b]")
x=A.ba("<\\s*(em|i)\\s*>",!1,!1,!1)
v=A.bQ(v,x,"[i]")
x=A.ba("<\\s*/\\s*(em|i)\\s*>",!1,!1,!1)
v=A.bQ(v,x,"[/i]")
x=A.ba("<\\s*u\\s*>",!1,!1,!1)
v=A.bQ(v,x,"[u]")
x=A.ba("<\\s*/\\s*u\\s*>",!1,!1,!1)
v=A.bQ(v,x,"[/u]")
x=A.ba("<\\s*h1[^>]*>",!1,!1,!1)
v=A.bQ(v,x,"[b][size=42]")
x=A.ba("<\\s*/\\s*h1\\s*>",!1,!1,!1)
v=A.bQ(v,x,w)
x=A.ba("<\\s*h2[^>]*>",!1,!1,!1)
v=A.bQ(v,x,"[b][size=32]")
x=A.ba("<\\s*/\\s*h2\\s*>",!1,!1,!1)
v=A.bQ(v,x,w)
x=A.ba("<\\s*h3[^>]*>",!1,!1,!1)
v=A.bQ(v,x,"[b][size=24]")
x=A.ba("<\\s*/\\s*h3\\s*>",!1,!1,!1)
v=A.bQ(v,x,w)
x=A.ba("<\\s*br\\s*/?\\s*>",!1,!1,!1)
v=A.bQ(v,x,"\n")
x=A.ba("<\\s*/\\s*(p|div)\\s*>",!1,!1,!1)
v=A.bQ(v,x,"\n\n")
x=A.ba("<\\s*(p|div)[^>]*>",!1,!1,!1)
v=A.bQ(v,x,"")
x=A.ba("<\\s*li[^>]*>",!1,!1,!1)
v=A.bQ(v,x,"\u2022 ")
x=A.ba("<\\s*/\\s*li\\s*>",!1,!1,!1)
v=A.bQ(v,x,"\n")
x=A.ba("<\\s*/?\\s*(ul|ol)[^>]*>",!1,!1,!1)
v=A.bQ(v,x,"")
x=A.ba("<[^>]+>",!0,!1,!1)
u=A.bQ(v,x,"")
v=A.bQ(u,"&nbsp;"," ")
v=A.bQ(v,"&amp;","&")
v=A.bQ(v,"&lt;","<")
v=A.bQ(v,"&gt;",">")
v=A.bQ(v,"&quot;",'"')
return C.e.l(A.bQ(v,"&#39;","'"))},
cBH(d){var x,w,v=C.e.l(d)
if(v.length===0)return null
x=C.e.b8(v,"#")?C.e.bX(v,1):v
if(x.length===6)x="FF"+x
if(x.length===8){w=A.cg(x,16)
if(w!=null)return A.co(w)}return null},
czE(d,e){var x,w,v,u=null,t=d
if(e.a)t=t.rw(C.a5)
if(e.b)t=t.bfr(D.hL)
if(e.c)t=t.bfm(C.eR)
w=e.d
if(w!=null)t=t.rv(w)
w=e.e
if(w!=null)t=t.bW(w)
if(e.f!=null)t=t.bg7(C.x3,C.eR)
w=e.r
x=w==null?u:C.e.l(w)
if(x!=null&&x.length!==0&&x.toLowerCase()!=="default")try{t=E.kz(x,u,u,u,t)}catch(v){}return t},
cCK(d,e,f){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null
if(C.e.q(d,"<")&&C.e.q(d,">"))d=B.cAY(d)
x=A.a([],y.p)
w=A.a([new B.XY()],y.b)
v=new B.c02(w,e,f,x)
u=new B.c05(w)
t=new B.c04(w)
for(s=$.cmM().BV(0,d),s=new A.Jz(s.a,s.b,s.c),r=y.a,q=0;s.A();){p=s.d
o=(p==null?r.a(p):p).b
n=o.index
if(n>q)v.$1(C.e.ai(d,q,n))
m=o[1]
l=o[2]
l.toString
k=o[3]
if(m==="/")t.$1(l)
else u.$2(l,k)
q=n+o[0].length}if(q<d.length)v.$1(C.e.bX(d,q))
if(x.length===0)x.push(A.fa(j,j,j,j,j,j,j,j,j,e,d))
return x},
kV(d,e,f){return new B.V0(f,d,e,null)},
XY:function XY(){var _=this
_.c=_.b=_.a=!1
_.r=_.f=_.e=_.d=null},
c_2:function c_2(){},
c_3:function c_3(){},
c02:function c02(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
c03:function c03(d){this.a=d},
c05:function c05(d){this.a=d},
c04:function c04(d){this.a=d},
V0:function V0(d,e,f,g){var _=this
_.c=d
_.d=e
_.e=f
_.a=g},
ao6:function ao6(d){this.d=d
this.c=this.a=null}},D,F,G
A=c[0]
C=c[2]
E=c[58]
B=a.updateHolder(c[52],B)
D=c[116]
F=c[57]
G=c[143]
B.XY.prototype={}
B.V0.prototype={
Y(){return new B.ao6(A.a([],y.o))},
gu(){return this.c}}
B.ao6.prototype={
n(){var x,w,v,u,t
for(x=this.d,w=x.length,v=0;v<x.length;x.length===w||(0,A.N)(x),++v){u=x[v]
t=u.db
if(t!=null){t.aJ()
u.db=null}u.mh()}this.aj()},
D(d){var x,w,v,u,t,s=null
for(x=this.d,w=x.length,v=0;v<x.length;x.length===w||(0,A.N)(x),++v){u=x[v]
t=u.db
if(t!=null){t.aJ()
u.db=null}u.mh()}C.f.V(x)
w=this.a
return A.cf0(A.fa(B.cCK(w.c,w.d,x),s,s,s,s,s,s,s,s,s,s),s,C.dJ,s,this.a.e)}}
var z=a.updateTypes([])
B.c_2.prototype={
$1(d){var x,w=d.qG(1)
if(w==null)w=""
x=d.qG(2)
if(x==null)x=""
return"[link="+w+"]"+x+"[/link]"},
$S:91}
B.c_3.prototype={
$1(d){var x,w,v,u,t,s=d.qG(1)
if(s==null)s=""
x=s.toLowerCase()
w=d.qG(2)
if(w==null)w=""
s=A.ba("color\\s*:\\s*([^;]+)",!0,!1,!1).q5(x)
v=s==null?null:s.b[1]
s=A.ba("font-size\\s*:\\s*([0-9.]+)",!0,!1,!1).q5(x)
u=s==null?null:s.b[1]
s=A.ba("font-family\\s*:\\s*([^;]+)",!0,!1,!1).q5(x)
t=s==null?null:s.b[1]
if(t!=null&&C.e.l(t).length!==0){s=A.ba("\\s+",!0,!1,!1)
s=C.e.l(A.bQ(t,s," "))
s=A.bQ(s,"'","")
w="[font="+A.bQ(s,'"',"")+"]"+w+"[/font]"}if(u!=null&&C.e.l(u).length!==0)w="[size="+u+"]"+w+"[/size]"
if(v!=null&&C.e.l(v).length!==0){s=A.ba("\\s+",!0,!1,!1)
w="[color="+C.e.l(A.bQ(v,s," "))+"]"+w+"[/color]"}return w},
$S:91}
B.c02.prototype={
$1(d){var x,w,v,u,t,s=this,r=null
if(d.length===0)return
x=C.f.gaU(s.a)
w=B.czE(s.b,x)
v=x.f
u=v==null?r:C.e.l(v)
if(u!=null&&u.length!==0){t=A.Dc(r,-1,r)
t.X=new B.c03(u)
s.c.push(t)
s.d.push(A.fa(r,r,r,r,r,t,r,r,r,w,d))}else s.d.push(A.fa(r,r,r,r,r,r,r,r,r,w,d))},
$S:1}
B.c03.prototype={
$0(){var x=0,w=A.m(y.f),v,u=this,t
var $async$$0=A.n(function(d,e){if(d===1)return A.j(e,w)
for(;;)switch(x){case 0:t=A.qE(u.a)
if(t==null){x=1
break}x=3
return A.d(F.w6(t,G.o4),$async$$0)
case 3:case 1:return A.k(v,w)}})
return A.l($async$$0,w)},
$S:2}
B.c05.prototype={
$2(d,e){var x,w,v=this.a,u=C.f.gaU(v),t=new B.XY()
t.a=u.a
t.b=u.b
t.c=u.c
t.d=u.d
t.e=u.e
t.f=u.f
t.r=u.r
switch(d){case"b":t.a=!0
break
case"i":t.b=!0
break
case"u":t.c=!0
break
case"size":x=A.bF(e==null?"":e)
if(x!=null)t.d=x
break
case"color":w=B.cBH(e==null?"":e)
if(w!=null)t.e=w
break
case"link":t.f=e==null?null:C.e.l(e)
break
case"font":t.r=e==null?null:C.e.l(e)
break}v.push(t)},
$S:286}
B.c04.prototype={
$1(d){var x=this.a
if(x.length<=1)return
x.pop()},
$S:1};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.XY,A.W)
w(A.d8,[B.c_2,B.c_3,B.c02,B.c04])
x(B.c03,A.dX)
x(B.c05,A.em)
x(B.V0,A.a2)
x(B.ao6,A.a3)})()
A.dl(b.typeUniverse,JSON.parse('{"V0":{"a2":[],"f":[]},"ao6":{"a3":["V0"]}}'))
var y={p:A.X("y<hY>"),o:A.X("y<jQ>"),b:A.X("y<XY>"),a:A.X("S6"),f:A.X("~")};(function constants(){D.hL=new A.a5t(1,"italic")
D.yB=new A.an(57898,"MaterialIcons",!1)
D.yC=new A.an(57941,"MaterialIcons",!1)
D.r4=new A.an(58530,"MaterialIcons",!1)
D.yL=new A.an(58569,"MaterialIcons",!1)
D.yO=new A.an(58710,"MaterialIcons",!1)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cLH","cmM",()=>A.ba("\\[(\\/?)(b|i|u|size|color|link|font)(?:=([^\\]]+))?\\]",!0,!1,!1))})()};
(a=>{a["4JCrCvCyKhgEfeWDCt2ts7+/ZJU="]=a.current})($__dart_deferred_initializers__);