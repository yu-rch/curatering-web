((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var A,C,E,B={
cAZ(d){var x,w="[/size][/b]\n",v=A.b8("\\r\\n?",!0,!1,!1),u=A.a1K(A.a1K(A.bP(d,v,"\n"),A.b8("<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",!1,!0,!1),new B.c_3(),null),A.b8("<span\\b[^>]*style=[\"']([^\"']+)[\"'][^>]*>(.*?)</span>",!1,!0,!1),new B.c_4(),null)
v=A.b8("<\\s*(strong|b)\\s*>",!1,!1,!1)
v=A.bP(u,v,"[b]")
x=A.b8("<\\s*/\\s*(strong|b)\\s*>",!1,!1,!1)
v=A.bP(v,x,"[/b]")
x=A.b8("<\\s*(em|i)\\s*>",!1,!1,!1)
v=A.bP(v,x,"[i]")
x=A.b8("<\\s*/\\s*(em|i)\\s*>",!1,!1,!1)
v=A.bP(v,x,"[/i]")
x=A.b8("<\\s*u\\s*>",!1,!1,!1)
v=A.bP(v,x,"[u]")
x=A.b8("<\\s*/\\s*u\\s*>",!1,!1,!1)
v=A.bP(v,x,"[/u]")
x=A.b8("<\\s*h1[^>]*>",!1,!1,!1)
v=A.bP(v,x,"[b][size=42]")
x=A.b8("<\\s*/\\s*h1\\s*>",!1,!1,!1)
v=A.bP(v,x,w)
x=A.b8("<\\s*h2[^>]*>",!1,!1,!1)
v=A.bP(v,x,"[b][size=32]")
x=A.b8("<\\s*/\\s*h2\\s*>",!1,!1,!1)
v=A.bP(v,x,w)
x=A.b8("<\\s*h3[^>]*>",!1,!1,!1)
v=A.bP(v,x,"[b][size=24]")
x=A.b8("<\\s*/\\s*h3\\s*>",!1,!1,!1)
v=A.bP(v,x,w)
x=A.b8("<\\s*br\\s*/?\\s*>",!1,!1,!1)
v=A.bP(v,x,"\n")
x=A.b8("<\\s*/\\s*(p|div)\\s*>",!1,!1,!1)
v=A.bP(v,x,"\n\n")
x=A.b8("<\\s*(p|div)[^>]*>",!1,!1,!1)
v=A.bP(v,x,"")
x=A.b8("<\\s*li[^>]*>",!1,!1,!1)
v=A.bP(v,x,"\u2022 ")
x=A.b8("<\\s*/\\s*li\\s*>",!1,!1,!1)
v=A.bP(v,x,"\n")
x=A.b8("<\\s*/?\\s*(ul|ol)[^>]*>",!1,!1,!1)
v=A.bP(v,x,"")
x=A.b8("<[^>]+>",!0,!1,!1)
u=A.bP(v,x,"")
v=A.bP(u,"&nbsp;"," ")
v=A.bP(v,"&amp;","&")
v=A.bP(v,"&lt;","<")
v=A.bP(v,"&gt;",">")
v=A.bP(v,"&quot;",'"')
return C.e.l(A.bP(v,"&#39;","'"))},
cBI(d){var x,w,v=C.e.l(d)
if(v.length===0)return null
x=C.e.b8(v,"#")?C.e.bX(v,1):v
if(x.length===6)x="FF"+x
if(x.length===8){w=A.ci(x,16)
if(w!=null)return A.cr(w)}return null},
czF(d,e){var x,w,v,u=null,t=d
if(e.a)t=t.rz(C.a5)
if(e.b)t=t.bfu(D.hT)
if(e.c)t=t.bfp(C.eR)
w=e.d
if(w!=null)t=t.rw(w)
w=e.e
if(w!=null)t=t.bW(w)
if(e.f!=null)t=t.bga(C.x9,C.eR)
w=e.r
x=w==null?u:C.e.l(w)
if(x!=null&&x.length!==0&&x.toLowerCase()!=="default")try{t=E.kz(x,u,u,u,t)}catch(v){}return t},
cCL(d,e,f){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j=null
if(C.e.q(d,"<")&&C.e.q(d,">"))d=B.cAZ(d)
x=A.a([],y.p)
w=A.a([new B.XW()],y.b)
v=new B.c03(w,e,f,x)
u=new B.c06(w)
t=new B.c05(w)
for(s=$.cmM().BV(0,d),s=new A.Jx(s.a,s.b,s.c),r=y.a,q=0;s.A();){p=s.d
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
kV(d,e,f){return new B.UZ(f,d,e,null)},
XW:function XW(){var _=this
_.c=_.b=_.a=!1
_.r=_.f=_.e=_.d=null},
c_3:function c_3(){},
c_4:function c_4(){},
c03:function c03(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
c04:function c04(d){this.a=d},
c06:function c06(d){this.a=d},
c05:function c05(d){this.a=d},
UZ:function UZ(d,e,f,g){var _=this
_.c=d
_.d=e
_.e=f
_.a=g},
ao4:function ao4(d){this.d=d
this.c=this.a=null}},D,F,G
A=c[0]
C=c[2]
E=c[58]
B=a.updateHolder(c[52],B)
D=c[116]
F=c[57]
G=c[143]
B.XW.prototype={}
B.UZ.prototype={
Y(){return new B.ao4(A.a([],y.o))},
gv(){return this.c}}
B.ao4.prototype={
n(){var x,w,v,u,t
for(x=this.d,w=x.length,v=0;v<x.length;x.length===w||(0,A.N)(x),++v){u=x[v]
t=u.db
if(t!=null){t.aJ()
u.db=null}u.mi()}this.aj()},
D(d){var x,w,v,u,t,s=null
for(x=this.d,w=x.length,v=0;v<x.length;x.length===w||(0,A.N)(x),++v){u=x[v]
t=u.db
if(t!=null){t.aJ()
u.db=null}u.mi()}C.f.V(x)
w=this.a
return A.cf0(A.fa(B.cCL(w.c,w.d,x),s,s,s,s,s,s,s,s,s,s),s,C.dG,s,this.a.e)}}
var z=a.updateTypes([])
B.c_3.prototype={
$1(d){var x,w=d.qH(1)
if(w==null)w=""
x=d.qH(2)
if(x==null)x=""
return"[link="+w+"]"+x+"[/link]"},
$S:85}
B.c_4.prototype={
$1(d){var x,w,v,u,t,s=d.qH(1)
if(s==null)s=""
x=s.toLowerCase()
w=d.qH(2)
if(w==null)w=""
s=A.b8("color\\s*:\\s*([^;]+)",!0,!1,!1).q6(x)
v=s==null?null:s.b[1]
s=A.b8("font-size\\s*:\\s*([0-9.]+)",!0,!1,!1).q6(x)
u=s==null?null:s.b[1]
s=A.b8("font-family\\s*:\\s*([^;]+)",!0,!1,!1).q6(x)
t=s==null?null:s.b[1]
if(t!=null&&C.e.l(t).length!==0){s=A.b8("\\s+",!0,!1,!1)
s=C.e.l(A.bP(t,s," "))
s=A.bP(s,"'","")
w="[font="+A.bP(s,'"',"")+"]"+w+"[/font]"}if(u!=null&&C.e.l(u).length!==0)w="[size="+u+"]"+w+"[/size]"
if(v!=null&&C.e.l(v).length!==0){s=A.b8("\\s+",!0,!1,!1)
w="[color="+C.e.l(A.bP(v,s," "))+"]"+w+"[/color]"}return w},
$S:85}
B.c03.prototype={
$1(d){var x,w,v,u,t,s=this,r=null
if(d.length===0)return
x=C.f.gaU(s.a)
w=B.czF(s.b,x)
v=x.f
u=v==null?r:C.e.l(v)
if(u!=null&&u.length!==0){t=A.Db(r,-1,r)
t.X=new B.c04(u)
s.c.push(t)
s.d.push(A.fa(r,r,r,r,r,t,r,r,r,w,d))}else s.d.push(A.fa(r,r,r,r,r,r,r,r,r,w,d))},
$S:1}
B.c04.prototype={
$0(){var x=0,w=A.l(y.f),v,u=this,t
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:t=A.qF(u.a)
if(t==null){x=1
break}x=3
return A.d(F.w4(t,G.o8),$async$$0)
case 3:case 1:return A.j(v,w)}})
return A.k($async$$0,w)},
$S:2}
B.c06.prototype={
$2(d,e){var x,w,v=this.a,u=C.f.gaU(v),t=new B.XW()
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
case"size":x=A.bE(e==null?"":e)
if(x!=null)t.d=x
break
case"color":w=B.cBI(e==null?"":e)
if(w!=null)t.e=w
break
case"link":t.f=e==null?null:C.e.l(e)
break
case"font":t.r=e==null?null:C.e.l(e)
break}v.push(t)},
$S:259}
B.c05.prototype={
$1(d){var x=this.a
if(x.length<=1)return
x.pop()},
$S:1};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.XW,A.W)
w(A.d9,[B.c_3,B.c_4,B.c03,B.c05])
x(B.c04,A.dY)
x(B.c06,A.en)
x(B.UZ,A.a2)
x(B.ao4,A.a3)})()
A.dl(b.typeUniverse,JSON.parse('{"UZ":{"a2":[],"f":[]},"ao4":{"a3":["UZ"]}}'))
var y={p:A.X("y<hZ>"),o:A.X("y<jQ>"),b:A.X("y<XW>"),a:A.X("S4"),f:A.X("~")};(function constants(){D.hT=new A.a5q(1,"italic")
D.yI=new A.an(57898,"MaterialIcons",!1)
D.yJ=new A.an(57941,"MaterialIcons",!1)
D.rb=new A.an(58530,"MaterialIcons",!1)
D.yS=new A.an(58569,"MaterialIcons",!1)
D.yV=new A.an(58710,"MaterialIcons",!1)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cLI","cmM",()=>A.b8("\\[(\\/?)(b|i|u|size|color|link|font)(?:=([^\\]]+))?\\]",!0,!1,!1))})()};
(a=>{a["CxDWpKMVzuywcxCh/jlqe72xsR0="]=a.current})($__dart_deferred_initializers__);