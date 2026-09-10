((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,B={
cqP(d,e){var x=new A.aI($.aW,e.i("aI<0>"))
A.iI(new B.aAc(d,x))
return x},
aAc:function aAc(d,e){this.a=d
this.b=e},
c5D(d){var x,w,v,u="created_at",t=d.h(0,"dish_ids"),s=t==null?d.h(0,"dishIds"):t
if(s==null)s=C.bu
t=A.aK(d.h(0,"id"))
if(t==null)t=""
x=A.aK(d.h(0,"name"))
if(x==null)x=""
if(y.i.b(s)){w=J.ch(s,new B.aR3(),y.w).cG(0,new B.aR4())
w=A.v(w,w.$ti.i("r.E"))}else w=C.P
v=A.kq(d.h(0,"archived"))
if(d.h(0,u)!=null)E.eo(J.w(d.h(0,u)))
return new B.f6(t,x,w,v===!0)},
cuO(){var x=new B.aaU($.a_())
x.aEV()
return x},
f6:function f6(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aR3:function aR3(){},
aR4:function aR4(){},
aaU:function aaU(d){var _=this
_.a=$
_.b=!1
_.I$=0
_.K$=d
_.aL$=_.aR$=0},
aR_:function aR_(d){this.a=d},
aR1:function aR1(){},
aR0:function aR0(){},
aR2:function aR2(d,e){this.a=d
this.b=e}}
J=c[1]
A=c[0]
C=c[2]
D=c[52]
E=c[50]
B=a.updateHolder(c[25],B)
B.f6.prototype={}
B.aaU.prototype={
aEV(){this.a=A.a([],y.k)
B.cqP(new B.aR_(this),y.v)},
mU(){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n
var $async$mU=A.m(function(d,e){if(d===1){u.push(e)
x=v}for(;;)switch(x){case 0:v=3
t.b=!0
t.a4()
x=6
return A.d($.bO().vW("/api/menu/set-menus"),$async$mU)
case 6:s=e
r=J.t(s,"setMenus")
if(!y.i.b(r))t.a=A.a([],y.k)
else{p=J.ch(r,new B.aR1(),y.e)
p=A.v(p,p.$ti.i("ab.E"))
t.a=p}t.b=!1
t.a4()
v=1
x=5
break
case 3:v=2
n=u.pop()
q=A.a9(n)
D.em().$1("Error loading set menus: "+A.h(q))
J.w(q)
t.b=!1
t.a4()
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$mU,w)},
gio(){var x,w=this.a
w===$&&A.b()
x=A.F(w).i("V<1>")
w=A.v(new A.V(w,new B.aR0(),x),x.i("r.E"))
return w},
RD(d,e){return this.bd3(d,e)},
bd3(d,e){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$RD=A.m(function(f,g){if(f===1){u.push(g)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bO().ea("/api/set-menus",A.Q(["name",C.e.m(e),"dishIds",d],y.w,y.b)),$async$RD)
case 6:s=g
r=B.c5D(y.y.a(J.t(s,"setMenu")))
o=t.a
o===$&&A.b()
o=A.v(o,y.e)
q=o
J.bS(q,r)
t.a=q
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
p=A.a9(m)
D.em().$1("Error adding set menu: "+A.h(p))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$RD,w)},
VP(d,e,f){return this.bqN(d,e,f)},
bqN(d,e,f){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$VP=A.m(function(g,h){if(g===1){u.push(h)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bO().kM("/api/set-menus/"+e,A.Q(["name",C.e.m(f),"dishIds",d],y.w,y.b)),$async$VP)
case 6:s=h
r=B.c5D(y.y.a(J.t(s,"setMenu")))
p=t.a
p===$&&A.b()
o=A.F(p).i("x<1,f6>")
p=A.v(new A.x(p,new B.aR2(e,r),o),o.i("ab.E"))
t.a=p
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
q=A.a9(m)
D.em().$1("Error updating set menu: "+A.h(q))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$VP,w)}}
var z=a.updateTypes(["f6(@)","I(f6)","f6(f6)"])
B.aAc.prototype={
$0(){var x,w,v,u,t,s,r=null
try{r=this.a.$0()}catch(v){x=A.a9(v)
w=A.be(v)
u=x
t=w
s=A.Er(u,t)
u=new A.h1(u,t)
this.b.km(u)
return}this.b.tI(r)},
$S:0}
B.aR3.prototype={
$1(d){return J.w(d)},
$S:13}
B.aR4.prototype={
$1(d){return d.length!==0},
$S:3}
B.aR_.prototype={
$0(){return this.a.mU()},
$S:2}
B.aR1.prototype={
$1(d){return B.c5D(y.y.a(d))},
$S:z+0}
B.aR0.prototype={
$1(d){return!d.d},
$S:z+1}
B.aR2.prototype={
$1(d){return d.a===this.a?this.b:d},
$S:z+2};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.eQ,[B.aAc,B.aR_])
w(B.f6,A.W)
x(A.dS,[B.aR3,B.aR4,B.aR1,B.aR0,B.aR2])
w(B.aaU,A.hT)})()
A.ey(b.typeUniverse,JSON.parse('{"aaU":{"aL":[]}}'))
var y={k:A.a4("A<f6>"),i:A.a4("Z<@>"),y:A.a4("R<e,@>"),e:A.a4("f6"),w:A.a4("e"),b:A.a4("@"),v:A.a4("~")};(function lazyInitializers(){var x=a.lazyFinal
x($,"cIz","fa",()=>B.cuO())})()};
(a=>{a["ke3aNuo5AAPGsfYEMJqh6l3C5TQ="]=a.current})($__dart_deferred_initializers__);
//# sourceMappingURL=main.dart.js_65.part.js.map
