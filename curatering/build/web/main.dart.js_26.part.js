((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,E,D={aGo:function aGo(){}},B
J=c[1]
A=c[0]
C=c[2]
F=c[28]
E=c[26]
D=a.updateHolder(c[13],D)
B=c[29]
D.aGo.prototype={
CJ(d){return this.auQ(d)},
auQ(d){var x=0,w=A.m(y.i),v,u,t,s,r,q
var $async$CJ=A.n(function(e,f){if(e===1)return A.j(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.ek(A.by("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a4.ca(d,null),null,C.lB).cr(F.f3),$async$CJ)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a4.bl(A.cr(A.cq(s.e)).bb(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.u(t.h(0,"message"))}catch(p){}throw A.q(A.an3(u,q.b))}s=q
if(C.e.k(A.cr(A.cq(s.e)).bb(s.w)).length===0){v=C.ie
x=1
break}s=q
t=C.a4.bl(A.cr(A.cq(s.e)).bb(s.w),null)
v=y.l.b(t)?A.aH(t,y.g,y.b):C.ie
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$CJ,w)},
a2b(d,e,f){return this.be9(d,e,f)},
be9(d,e,f){var x=0,w=A.m(y.i),v
var $async$a2b=A.n(function(g,h){if(g===1)return A.j(h,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/yolo-sam-infer",A.M(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$a2b,w)},
K3(d,e,f){return this.aA8(d,e,f)},
aA8(d,e,f){var x=0,w=A.m(y.i),v
var $async$K3=A.n(function(g,h){if(g===1)return A.j(h,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/swap-colors",A.M(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$K3,w)},
TW(d,e,f,g,h,i,j,k){return this.atB(d,e,f,g,h,i,j,k)},
atB(d,e,f,g,h,i,j,k){var x=0,w=A.m(y.i),v
var $async$TW=A.n(function(l,m){if(l===1)return A.j(m,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/theme-search",A.M(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$TW,w)},
a1u(d){return this.bbW(d)},
bbW(d){var x=0,w=A.m(y.i),v
var $async$a1u=A.n(function(e,f){if(e===1)return A.j(f,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/extract-objects",A.M(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$a1u,w)},
a_H(d){return this.b7c(d)},
b7c(d){var x=0,w=A.m(y.i),v
var $async$a_H=A.n(function(e,f){if(e===1)return A.j(f,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/analyze-base",A.M(["baseImageBase64",d],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$a_H,w)},
a_R(d,e){return this.b7y(d,e)},
b7y(d,e){var x=0,w=A.m(y.i),v
var $async$a_R=A.n(function(f,g){if(f===1)return A.j(g,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/auto-place",A.M(["freeSpaces",d,"objects",e],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$a_R,w)},
a3W(d,e){return this.biX(d,e)},
biX(d,e){var x=0,w=A.m(y.i),v
var $async$a3W=A.n(function(f,g){if(f===1)return A.j(g,w)
for(;;)switch(x){case 0:v=$.bM().dI("/api/public/events/theme-design/render-composite",A.M(["baseImageBase64",d,"objects",e],y.g,y.b)).cr(B.fU)
x=1
break
case 1:return A.k(v,w)}})
return A.l($async$a3W,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aGo,A.Z)})()
var y={i:A.an("R<e,@>"),l:A.an("R<@,@>"),g:A.an("e"),b:A.an("@")};(function constants(){B.fU=new A.bC(18e7)
B.Hz=new A.ah(E.Hg,null,null,null,null)
B.GM=new A.ai(57785,"MaterialIcons",!1)
B.yf=new A.ah(E.ng,null,null,null,null)
B.GV=new A.ai(58460,"MaterialIcons",!0)
B.AP=new A.V(1/0,48)
B.Bq=new A.D(!0,null,null,null,null,null,13,C.aw,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.Bw=new A.D(!0,C.cF,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.BA=new A.D(!0,null,null,null,null,null,12,C.aw,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a0K=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cyX","rt",()=>new D.aGo())})()};
(a=>{a["klxtVMfSGw7pVl9FQ1RdiRbII+U="]=a.current})($__dart_deferred_initializers__);