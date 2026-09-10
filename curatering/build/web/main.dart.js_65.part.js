((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,B={
cqY(d,e){var x=new A.aI($.aW,e.i("aI<0>"))
A.iI(new B.aAb(d,x))
return x},
aAb:function aAb(d,e){this.a=d
this.b=e},
c5K(d){var x,w,v,u="created_at",t=d.h(0,"dish_ids"),s=t==null?d.h(0,"dishIds"):t
if(s==null)s=C.bu
t=A.aK(d.h(0,"id"))
if(t==null)t=""
x=A.aK(d.h(0,"name"))
if(x==null)x=""
if(y.i.b(s)){w=J.ci(s,new B.aR2(),y.w).cH(0,new B.aR3())
w=A.w(w,w.$ti.i("r.E"))}else w=C.O
v=A.kq(d.h(0,"archived"))
if(d.h(0,u)!=null)E.ep(J.v(d.h(0,u)))
return new B.f6(t,x,w,v===!0)},
cuX(){var x=new B.aaS($.a_())
x.aEZ()
return x},
f6:function f6(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aR2:function aR2(){},
aR3:function aR3(){},
aaS:function aaS(d){var _=this
_.a=$
_.b=!1
_.I$=0
_.J$=d
_.aL$=_.aR$=0},
aQZ:function aQZ(d){this.a=d},
aR0:function aR0(){},
aR_:function aR_(){},
aR1:function aR1(d,e){this.a=d
this.b=e}}
J=c[1]
A=c[0]
C=c[2]
D=c[52]
E=c[50]
B=a.updateHolder(c[25],B)
B.f6.prototype={}
B.aaS.prototype={
aEZ(){this.a=A.a([],y.k)
B.cqY(new B.aQZ(this),y.v)},
mU(){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n
var $async$mU=A.m(function(d,e){if(d===1){u.push(e)
x=v}for(;;)switch(x){case 0:v=3
t.b=!0
t.a4()
x=6
return A.d($.bM().vX("/api/menu/set-menus"),$async$mU)
case 6:s=e
r=J.t(s,"setMenus")
if(!y.i.b(r))t.a=A.a([],y.k)
else{p=J.ci(r,new B.aR0(),y.e)
p=A.w(p,p.$ti.i("ab.E"))
t.a=p}t.b=!1
t.a4()
v=1
x=5
break
case 3:v=2
n=u.pop()
q=A.a9(n)
D.en().$1("Error loading set menus: "+A.h(q))
J.v(q)
t.b=!1
t.a4()
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$mU,w)},
gil(){var x,w=this.a
w===$&&A.b()
x=A.E(w).i("V<1>")
w=A.w(new A.V(w,new B.aR_(),x),x.i("r.E"))
return w},
RF(d,e){return this.bdd(d,e)},
bdd(d,e){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$RF=A.m(function(f,g){if(f===1){u.push(g)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bM().e0("/api/set-menus",A.Q(["name",C.e.m(e),"dishIds",d],y.w,y.b)),$async$RF)
case 6:s=g
r=B.c5K(y.y.a(J.t(s,"setMenu")))
o=t.a
o===$&&A.b()
o=A.w(o,y.e)
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
D.en().$1("Error adding set menu: "+A.h(p))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$RF,w)},
VS(d,e,f){return this.bqY(d,e,f)},
bqY(d,e,f){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$VS=A.m(function(g,h){if(g===1){u.push(h)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bM().kN("/api/set-menus/"+e,A.Q(["name",C.e.m(f),"dishIds",d],y.w,y.b)),$async$VS)
case 6:s=h
r=B.c5K(y.y.a(J.t(s,"setMenu")))
p=t.a
p===$&&A.b()
o=A.E(p).i("x<1,f6>")
p=A.w(new A.x(p,new B.aR1(e,r),o),o.i("ab.E"))
t.a=p
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
q=A.a9(m)
D.en().$1("Error updating set menu: "+A.h(q))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$VS,w)}}
var z=a.updateTypes(["f6(@)","I(f6)","f6(f6)"])
B.aAb.prototype={
$0(){var x,w,v,u,t,s,r=null
try{r=this.a.$0()}catch(v){x=A.a9(v)
w=A.be(v)
u=x
t=w
s=A.Eq(u,t)
u=new A.h1(u,t)
this.b.kl(u)
return}this.b.tI(r)},
$S:0}
B.aR2.prototype={
$1(d){return J.v(d)},
$S:13}
B.aR3.prototype={
$1(d){return d.length!==0},
$S:3}
B.aQZ.prototype={
$0(){return this.a.mU()},
$S:2}
B.aR0.prototype={
$1(d){return B.c5K(y.y.a(d))},
$S:z+0}
B.aR_.prototype={
$1(d){return!d.d},
$S:z+1}
B.aR1.prototype={
$1(d){return d.a===this.a?this.b:d},
$S:z+2};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.eR,[B.aAb,B.aQZ])
w(B.f6,A.W)
x(A.dT,[B.aR2,B.aR3,B.aR0,B.aR_,B.aR1])
w(B.aaS,A.hT)})()
A.ey(b.typeUniverse,JSON.parse('{"aaS":{"aL":[]}}'))
var y={k:A.a4("A<f6>"),i:A.a4("Z<@>"),y:A.a4("R<e,@>"),e:A.a4("f6"),w:A.a4("e"),b:A.a4("@"),v:A.a4("~")};(function lazyInitializers(){var x=a.lazyFinal
x($,"cII","fa",()=>B.cuX())})()};
(a=>{a["7GhE82BqoBNzW06FcdhvQ5YGgdM="]=a.current})($__dart_deferred_initializers__);