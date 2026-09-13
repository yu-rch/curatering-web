((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
cc_(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ays(),m=new B.ayr(),l=new B.ayq(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.l(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bB("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.l(A.h(k==null?"":k))
w=n.$1(d.h(0,"theme_tokens"))
v=n.$1(d.h(0,"lighting_tokens"))
u=n.$1(d.h(0,"style_tokens"))
t=n.$1(d.h(0,"decor_tokens"))
s=n.$1(d.h(0,"decor_elements"))
r=d.h(0,"visual_keywords")
n=n.$1(r==null?d.h(0,"visual_direction"):r)
r=d.h(0,"recommended_strength")
r=m.$1(r==null?d.h(0,"strength"):r)
m=m.$1(d.h(0,"cfg_scale"))
q=new B.ayp().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.u(o)
return new B.a4X(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aOk(d){var x=y.w,w=y.b
return y.B.b(d)?A.ay(d,x,w):A.H(x,w)},
ceR(d){var x,w,v=B.aOk(d.h(0,"output")),u=B.aOk(v.h(0,"result"))
if(u.a!==0)return u
x=B.aOk(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aOk(d.h(0,"result"))
if(w.a!==0)return w
return d},
Sz(d,e){return B.cvb(d,e)},
cvb(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$Sz=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(A.xT().length===0)A.ap(A.bB("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.eA(d,k,y.b)
J.au(s,"task_type","event_prompt_expansion")
r=s
s=A.bx(A.xT()+"/api/public/runpod/nlp/run",0,null)
j=A.N(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.es(s,C.a6.cn(A.N(["input",r],k,i),null),null,j).cw(C.qA),$async$Sz)
case 7:q=a0
if(q.b!==200)A.c6f(q)
s=q
p=i.a(C.a6.bq(A.ch(A.cg(s.e)).b6(s.w),null))
o=A.aak(J.t(p,"status"))
n=A.ceQ(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cc_(B.ceR(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bB(A.aOj(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bB("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aal(n),$async$Sz)
case 8:m=a0
s=B.cc_(B.ceR(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a5(g)
s=A.bB("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$Sz,w)},
aal(d){return B.cv9(d)},
cv9(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aal=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.fJ(C.qB,null,l),$async$aal)
case 5:++g
u=7
x=10
return A.d(A.fE(A.bx(A.xT()+"/api/public/runpod/nlp/status/"+A.eR(2,d,C.bd,!1),0,null),null).cw(C.fn),$async$aal)
case 10:s=a1
if(s.b===429){j=A.bB("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a6.bq(A.ch(A.cg(j.e)).b6(j.w),null))
q=A.aak(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bB(A.aOj(r))
throw A.p(j)}}else A.c6f(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a5(e)
if(m.b(j)){p=j
o=J.u(p)
if(J.ji(o,"Job failed")||J.ji(o,"AI generation exceeded")||J.ji(o,"Worker returned"))throw e
f=p
A.a1x("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1x("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bB("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aal,w)},
a4X:function a4X(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n
_.Q=o
_.as=p
_.at=q},
ays:function ays(){},
ayt:function ayt(){},
ayu:function ayu(){},
ayr:function ayr(){},
ayp:function ayp(){},
ayq:function ayq(){}},D
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[16],B)
D=c[40]
B.a4X.prototype={
avF(){var x,w,v=this,u=A.H(y.w,y.b)
u.k(0,"positive_prompt",v.a)
x=v.b
if(x.length!==0)u.k(0,"negative_prompt",x)
u.k(0,"theme_tokens",v.c)
u.k(0,"lighting_tokens",v.d)
u.k(0,"style_tokens",v.e)
u.k(0,"decor_tokens",v.f)
u.k(0,"decor_elements",v.r)
u.k(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.k(0,"recommended_strength",x)
if(w)u.k(0,"strength",x)
x=v.y
if(x!=null)u.k(0,"cfg_scale",x)
x=v.z
if(x!=null)u.k(0,"steps",x)
x=v.Q
if(x!=null)u.k(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.k(0,"mode",x)
x=v.at
if(x!=null)u.k(0,"transformation_plan",x)
u.k(0,"nlp_expansion",v.bn())
return u},
bn(){var x,w,v=this,u=A.H(y.w,y.b)
u.k(0,"positive_prompt",v.a)
u.k(0,"negative_prompt",v.b)
u.k(0,"theme_tokens",v.c)
u.k(0,"lighting_tokens",v.d)
u.k(0,"style_tokens",v.e)
u.k(0,"decor_tokens",v.f)
u.k(0,"decor_elements",v.r)
u.k(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.k(0,"recommended_strength",x)
if(w)u.k(0,"strength",x)
x=v.y
if(x!=null)u.k(0,"cfg_scale",x)
x=v.z
if(x!=null)u.k(0,"steps",x)
x=v.Q
if(x!=null)u.k(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.k(0,"mode",x)
x=v.at
if(x!=null)u.k(0,"transformation_plan",x)
return u}}
var z=a.updateTypes([])
B.ays.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bz:d
x=J.c9(x,new B.ayt(),y.w).cG(0,new B.ayu())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:299}
B.ayt.prototype={
$1(d){return C.e.l(A.h(d))},
$S:14}
B.ayu.prototype={
$1(d){return d.length!==0},
$S:4}
B.ayr.prototype={
$1(d){if(typeof d=="number")return d
return A.bA(A.h(d))},
$S:450}
B.ayp.prototype={
$1(d){if(typeof d=="number")return C.i.aJ(d)
return A.ce(A.h(d),null)},
$S:1169}
B.ayq.prototype={
$1(d){if(y.B.b(d))return A.ay(d,y.w,y.b)
return null},
$S:418};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a4X,A.a8)
w(A.ht,[B.ays,B.ayt,B.ayu,B.ayr,B.ayp,B.ayq])})()
var y={q:A.ak("a4X"),g:A.ak("cv"),y:A.ak("U<e,@>"),B:A.ak("U<@,@>"),w:A.ak("e"),b:A.ak("@"),d:A.ak("a_<@>?")};(function constants(){D.Ie=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["YZZK38OhOUcoknFipI4t3K5Jx6c="]=a.current})($__dart_deferred_initializers__);