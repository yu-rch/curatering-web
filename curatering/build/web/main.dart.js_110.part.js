((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
cra(d,e){var x=new A.aI($.aZ,e.i("aI<0>"))
A.iJ(new B.aAj(d,x))
return x},
aAj:function aAj(d,e){this.a=d
this.b=e},
c5S(d){var x,w,v,u="created_at",t=d.h(0,"dish_ids"),s=t==null?d.h(0,"dishIds"):t
if(s==null)s=C.bD
t=A.aL(d.h(0,"id"))
if(t==null)t=""
x=A.aL(d.h(0,"name"))
if(x==null)x=""
if(y.i.b(s)){w=J.cg(s,new B.aRe(),y.w).cI(0,new B.aRf())
w=A.v(w,w.$ti.i("r.E"))}else w=C.P
v=A.ks(d.h(0,"archived"))
if(d.h(0,u)!=null)E.et(J.w(d.h(0,u)))
return new B.f9(t,x,w,v===!0)},
cvb(){var x=new B.aaZ($.a0())
x.aF4()
return x},
f9:function f9(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aRe:function aRe(){},
aRf:function aRf(){},
aaZ:function aaZ(d){var _=this
_.a=$
_.b=!1
_.I$=0
_.J$=d
_.aN$=_.aJ$=0},
aRa:function aRa(d){this.a=d},
aRc:function aRc(){},
aRb:function aRb(){},
aRd:function aRd(d,e){this.a=d
this.b=e}},D,E
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[34],B)
D=c[83]
E=c[80]
B.f9.prototype={}
B.aaZ.prototype={
aF4(){this.a=A.a([],y.k)
B.cra(new B.aRa(this),y.v)},
mT(){var x=0,w=A.m(y.v),v=1,u=[],t=this,s,r,q,p,o,n
var $async$mT=A.n(function(d,e){if(d===1){u.push(e)
x=v}for(;;)switch(x){case 0:v=3
t.b=!0
t.a4()
x=6
return A.d($.bN().vV("/api/menu/set-menus"),$async$mT)
case 6:s=e
r=J.t(s,"setMenus")
if(!y.i.b(r))t.a=A.a([],y.k)
else{p=J.cg(r,new B.aRc(),y.e)
p=A.v(p,p.$ti.i("ab.E"))
t.a=p}t.b=!1
t.a4()
v=1
x=5
break
case 3:v=2
n=u.pop()
q=A.a9(n)
D.er().$1("Error loading set menus: "+A.h(q))
J.w(q)
t.b=!1
t.a4()
x=5
break
case 2:x=1
break
case 5:return A.k(null,w)
case 1:return A.j(u.at(-1),w)}})
return A.l($async$mT,w)},
gil(){var x,w=this.a
w===$&&A.b()
x=A.F(w).i("V<1>")
w=A.v(new A.V(w,new B.aRb(),x),x.i("r.E"))
return w},
RF(d,e){return this.bdn(d,e)},
bdn(d,e){var x=0,w=A.m(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$RF=A.n(function(f,g){if(f===1){u.push(g)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bN().e0("/api/set-menus",A.Q(["name",C.e.l(e),"dishIds",d],y.w,y.b)),$async$RF)
case 6:s=g
r=B.c5S(y.y.a(J.t(s,"setMenu")))
o=t.a
o===$&&A.b()
o=A.v(o,y.e)
q=o
J.bT(q,r)
t.a=q
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
p=A.a9(m)
D.er().$1("Error adding set menu: "+A.h(p))
throw m
x=5
break
case 2:x=1
break
case 5:return A.k(null,w)
case 1:return A.j(u.at(-1),w)}})
return A.l($async$RF,w)},
VT(d,e,f){return this.bra(d,e,f)},
bra(d,e,f){var x=0,w=A.m(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$VT=A.n(function(g,h){if(g===1){u.push(h)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bN().kJ("/api/set-menus/"+e,A.Q(["name",C.e.l(f),"dishIds",d],y.w,y.b)),$async$VT)
case 6:s=h
r=B.c5S(y.y.a(J.t(s,"setMenu")))
p=t.a
p===$&&A.b()
o=A.F(p).i("x<1,f9>")
p=A.v(new A.x(p,new B.aRd(e,r),o),o.i("ab.E"))
t.a=p
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
q=A.a9(m)
D.er().$1("Error updating set menu: "+A.h(q))
throw m
x=5
break
case 2:x=1
break
case 5:return A.k(null,w)
case 1:return A.j(u.at(-1),w)}})
return A.l($async$VT,w)}}
var z=a.updateTypes(["f9(@)","H(f9)","f9(f9)"])
B.aAj.prototype={
$0(){var x,w,v,u,t,s,r=null
try{r=this.a.$0()}catch(v){x=A.a9(v)
w=A.be(v)
u=x
t=w
s=A.Es(u,t)
u=new A.h2(u,t)
this.b.kj(u)
return}this.b.tH(r)},
$S:0}
B.aRe.prototype={
$1(d){return J.w(d)},
$S:13}
B.aRf.prototype={
$1(d){return d.length!==0},
$S:3}
B.aRa.prototype={
$0(){return this.a.mT()},
$S:2}
B.aRc.prototype={
$1(d){return B.c5S(y.y.a(d))},
$S:z+0}
B.aRb.prototype={
$1(d){return!d.d},
$S:z+1}
B.aRd.prototype={
$1(d){return d.a===this.a?this.b:d},
$S:z+2};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.dP,[B.aAj,B.aRa])
w(B.f9,A.X)
x(A.d0,[B.aRe,B.aRf,B.aRc,B.aRb,B.aRd])
w(B.aaZ,A.hG)})()
A.dd(b.typeUniverse,JSON.parse('{"aaZ":{"aJ":[]}}'))
var y={k:A.W("y<f9>"),i:A.W("a_<@>"),y:A.W("R<e,@>"),e:A.W("f9"),w:A.W("e"),b:A.W("@"),v:A.W("~")};(function lazyInitializers(){var x=a.lazyFinal
x($,"cIZ","fd",()=>B.cvb())})()};
(a=>{a["8UX5K6vLAPGdFXp/JoJ14vhSZjU="]=a.current})($__dart_deferred_initializers__);