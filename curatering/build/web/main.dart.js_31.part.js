((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
cbf(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayp(),m=new B.ayo(),l=new B.ayn(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.m(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bB("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.m(A.h(k==null?"":k))
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
q=new B.aym().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.w(o)
return new B.a4Y(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aO6(d){var x=y.w,w=y.b
return y.B.b(d)?A.aD(d,x,w):A.H(x,w)},
ce5(d){var x,w,v=B.aO6(d.h(0,"output")),u=B.aO6(v.h(0,"result"))
if(u.a!==0)return u
x=B.aO6(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aO6(d.h(0,"result"))
if(w.a!==0)return w
return d},
SP(d,e){return B.cui(d,e)},
cui(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SP=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.yc().length===0)A.aq(A.bB("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.f1(d,k,y.b)
J.az(s,"task_type","event_prompt_expansion")
r=s
s=A.bF(D.yc()+"/api/public/runpod/nlp/run",0,null)
j=A.Q(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.eH(s,C.a4.cr(A.Q(["input",r],k,i),null),null,j).cM(C.qB),$async$SP)
case 7:q=a0
if(q.b!==200)D.c5w(q)
s=q
p=i.a(C.a4.bu(A.cG(A.cF(s.e)).ba(s.w),null))
o=D.aah(J.t(p,"status"))
n=D.ce4(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cbf(B.ce5(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bB(D.aO5(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bB("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aai(n),$async$SP)
case 8:m=a0
s=B.cbf(B.ce5(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a9(g)
s=A.bB("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$SP,w)},
aai(d){return B.cug(d)},
cug(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aai=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.hm(E.qD,null,l),$async$aai)
case 5:++g
u=7
x=10
return A.d(A.hh(A.bF(D.yc()+"/api/public/runpod/nlp/status/"+A.f9(2,d,C.bb,!1),0,null),null).cM(F.fh),$async$aai)
case 10:s=a1
if(s.b===429){j=A.bB("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a4.bu(A.cG(A.cF(j.e)).ba(j.w),null))
q=D.aah(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bB(D.aO5(r))
throw A.p(j)}}else D.c5w(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a9(e)
if(m.b(j)){p=j
o=J.w(p)
if(J.jy(o,"Job failed")||J.jy(o,"AI generation exceeded")||J.jy(o,"Worker returned"))throw e
f=p
A.a1D("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1D("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bB("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aai,w)},
a4Y:function a4Y(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
ayp:function ayp(){},
ayq:function ayq(){},
ayr:function ayr(){},
ayo:function ayo(){},
aym:function aym(){},
ayn:function ayn(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[24]
E=c[73]
F=c[76]
B=a.updateHolder(c[15],B)
G=c[87]
B.a4Y.prototype={
avm(){var x,w,v=this,u=A.H(y.w,y.b)
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
u.k(0,"nlp_expansion",v.bo())
return u},
bo(){var x,w,v=this,u=A.H(y.w,y.b)
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
B.ayp.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bu:d
x=J.ch(x,new B.ayq(),y.w).cG(0,new B.ayr())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:247}
B.ayq.prototype={
$1(d){return C.e.m(A.h(d))},
$S:13}
B.ayr.prototype={
$1(d){return d.length!==0},
$S:3}
B.ayo.prototype={
$1(d){if(typeof d=="number")return d
return A.bE(A.h(d))},
$S:302}
B.aym.prototype={
$1(d){if(typeof d=="number")return C.i.aJ(d)
return A.co(A.h(d),null)},
$S:726}
B.ayn.prototype={
$1(d){if(y.B.b(d))return A.aD(d,y.w,y.b)
return null},
$S:294};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a4Y,A.W)
w(A.dS,[B.ayp,B.ayq,B.ayr,B.ayo,B.aym,B.ayn])})()
var y={q:A.a4("a4Y"),g:A.a4("cq"),y:A.a4("R<e,@>"),B:A.a4("R<@,@>"),w:A.a4("e"),b:A.a4("@"),d:A.a4("Z<@>?")};(function constants(){G.Ih=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["AuppkAEEhJdjw55i7dFVPU2egDg="]=a.current})($__dart_deferred_initializers__);
//# sourceMappingURL=main.dart.js_31.part.js.map
