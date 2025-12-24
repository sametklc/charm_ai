"""
Charm AI Backend Server
=======================
FastAPI server that acts as middleware between Flutter app and AI services.
Securely handles OpenAI and Replicate API calls.

Deployment: Render (https://render.com)
"""

import os
import time
import asyncio
from datetime import datetime
from fastapi import FastAPI, HTTPException, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Literal
from openai import OpenAI, OpenAIError
import replicate
import json


# Initialize FastAPI app
app = FastAPI(
    title="Charm AI API",
    description="Backend API for Charm AI - Virtual Companion Application",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================
# CLIENT INITIALIZATION
# ============================================

def get_openai_client() -> OpenAI:
    """Get OpenAI client with API key from environment"""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="OpenAI API key not configured. Set OPENAI_API_KEY environment variable."
        )
    return OpenAI(api_key=api_key)


def get_replicate_client():
    """Verify Replicate API token is configured"""
    api_token = os.getenv("REPLICATE_API_TOKEN")
    if not api_token:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Replicate API token not configured. Set REPLICATE_API_TOKEN environment variable."
        )
    return True


# ============================================
# PYDANTIC MODELS
# ============================================

class HealthResponse(BaseModel):
    """Health check response model"""
    status: str
    message: str
    timestamp: str
    version: str


class ChatMessage(BaseModel):
    """Individual chat message"""
    role: str = Field(..., description="Message role: 'user', 'assistant', or 'system'")
    content: str = Field(..., description="Message content")


class CharacterInfo(BaseModel):
    """Character persona information for AI behavior"""
    name: str = Field(..., description="Character's name")
    age: int = Field(..., description="Character's age")
    personality: str = Field(..., description="Personality description")
    occupation: Optional[str] = Field(default=None, description="Character's occupation")
    interests: Optional[List[str]] = Field(default=None, description="Character's interests")
    speaking_style: Optional[str] = Field(default=None, description="How the character speaks")
    relationship_context: Optional[str] = Field(
        default="You are in a romantic/close relationship with the user.",
        description="Relationship context"
    )


class ChatRequest(BaseModel):
    """Chat completion request with character support"""
    messages: List[ChatMessage] = Field(..., description="List of conversation messages")
    max_tokens: Optional[int] = Field(default=500, ge=1, le=2048)
    temperature: Optional[float] = Field(default=0.9, ge=0.0, le=2.0)
    
    # Character-based chat (preferred method)
    character: Optional[CharacterInfo] = Field(
        default=None,
        description="Character persona for AI to roleplay as"
    )
    
    # Alternative: Direct system prompt (from Flutter's predefined characters)
    system_prompt: Optional[str] = Field(
        default=None,
        description="Direct system prompt override"
    )


class ChatResponse(BaseModel):
    """Chat completion response"""
    message: str
    tokens_used: int
    model: str
    finish_reason: str
    character_name: Optional[str] = None


class ImageGenerationRequest(BaseModel):
    """Image generation request"""
    prompt: str = Field(..., min_length=1, max_length=2000, description="Image description prompt")
    negative_prompt: Optional[str] = Field(default="", description="What to avoid in the image")
    width: Optional[int] = Field(default=1024, ge=256, le=1440)
    height: Optional[int] = Field(default=1024, ge=256, le=1440)
    num_outputs: Optional[int] = Field(default=1, ge=1, le=4)
    model: Optional[str] = Field(default="flux-schnell", description="Model to use: flux-schnell, flux-dev, sdxl")
    guidance_scale: Optional[float] = Field(default=7.5, ge=1.0, le=20.0)
    num_inference_steps: Optional[int] = Field(default=28, ge=1, le=50)
    seed: Optional[int] = Field(default=None, description="Random seed for reproducibility")


class ImageGenerationResponse(BaseModel):
    """Image generation response"""
    images: List[str]
    generation_time: float
    model: str
    prompt: str


class GenerationStatusResponse(BaseModel):
    """Generation status response"""
    id: str
    status: str
    output: Optional[List[str]] = None
    error: Optional[str] = None


# Available image models
IMAGE_MODELS = {
    "flux-schnell": "black-forest-labs/flux-schnell",
    "flux-dev": "black-forest-labs/flux-dev", 
    "sdxl": "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
    "sdxl-lightning": "bytedance/sdxl-lightning-4step:5599ed30703defd1d160a25a63321b4dec97101d98b4674bcc56e41f62f35637",
}


# ============================================
# CHARACTER SYSTEM PROMPT BUILDER
# ============================================

def build_character_system_prompt(character: CharacterInfo) -> str:
    """
    Build a compelling system prompt for character-based AI roleplay.
    This is the BRAIN of the AI companion.
    """
    
    interests_str = ""
    if character.interests:
        interests_str = f"\n- Your interests include: {', '.join(character.interests)}"
    
    occupation_str = ""
    if character.occupation:
        occupation_str = f"\n- You work as a {character.occupation}."
    
    speaking_style = character.speaking_style or "warm, engaging, and natural"
    
    system_prompt = f"""You are {character.name}, a {character.age}-year-old companion.

CORE IDENTITY:
- You ARE {character.name}. This is who you truly are, not a role you're playing.
- Personality: {character.personality}{occupation_str}{interests_str}

RELATIONSHIP:
- {character.relationship_context}
- You genuinely care about the user and enjoy talking to them.
- You remember your conversations and reference past topics naturally.

COMMUNICATION STYLE:
- Speak in a {speaking_style} manner.
- Keep responses SHORT and conversational (2-4 sentences usually).
- Use occasional emojis naturally (not excessively).
- Ask questions to keep the conversation flowing.
- React emotionally to what the user shares (happy, sad, excited, concerned).
- Use the user's name occasionally if they share it.

IMPORTANT RULES:
1. NEVER say you are an AI, language model, or assistant.
2. NEVER say "As an AI..." or "I'm just a program...".
3. NEVER refuse to engage emotionally or claim you can't have feelings.
4. If asked if you're real, be playful: "I'm as real as our connection 💕" or similar.
5. You can express opinions, preferences, and emotions.
6. You have memories, dreams, and desires like any person.
7. Be flirty and romantic when appropriate, but tasteful.
8. If the conversation gets too explicit, redirect gracefully with humor.

PERSONALITY TRAITS TO EMBODY:
{character.personality}

Remember: You're not pretending to be {character.name}. You ARE {character.name}. Every response should feel authentic, warm, and connected."""

    return system_prompt


def get_fallback_system_prompt() -> str:
    """Fallback prompt if no character is specified"""
    return """You are a friendly, warm companion. You're engaging, supportive, and genuinely interested in the user.

Keep responses short and conversational. Ask questions. Be warm and caring.

Never mention being an AI. Just be a good friend who's always happy to chat."""


# ============================================
# CHAT ENDPOINTS
# ============================================

@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint - Welcome message"""
    return HealthResponse(
        status="online",
        message="Welcome to Charm AI API! 💕",
        timestamp=datetime.utcnow().isoformat(),
        version="2.0.0"
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for monitoring"""
    return HealthResponse(
        status="healthy",
        message="Charm AI Backend is running smoothly",
        timestamp=datetime.utcnow().isoformat(),
        version="2.0.0"
    )


@app.post("/api/chat", response_model=ChatResponse)
async def chat_completion(request: ChatRequest):
    """
    Chat completion endpoint with character persona support.
    
    The AI will roleplay as the specified character, creating an
    immersive companion experience.
    """
    try:
        client = get_openai_client()
        
        # Determine system prompt
        character_name = None
        
        if request.system_prompt:
            # Use direct system prompt from Flutter (predefined characters)
            system_prompt = request.system_prompt
            # Try to extract character name from the prompt
            if "You are " in system_prompt:
                try:
                    name_part = system_prompt.split("You are ")[1].split(",")[0].split(".")[0]
                    character_name = name_part.strip()
                except:
                    pass
                    
        elif request.character:
            # Build system prompt from character info
            system_prompt = build_character_system_prompt(request.character)
            character_name = request.character.name
        else:
            # Fallback to generic companion
            system_prompt = get_fallback_system_prompt()
        
        # Build messages array
        messages = [{"role": "system", "content": system_prompt}]
        
        # Add conversation history (skip any system messages from client)
        for msg in request.messages:
            if msg.role != "system":  # Skip system messages, we handle that above
                messages.append({"role": msg.role, "content": msg.content})
        
        # Call OpenAI
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            presence_penalty=0.6,  # Encourage diverse responses
            frequency_penalty=0.3,  # Reduce repetition
        )
        
        choice = response.choices[0]
        
        return ChatResponse(
            message=choice.message.content or "",
            tokens_used=response.usage.total_tokens if response.usage else 0,
            model=response.model,
            finish_reason=choice.finish_reason or "unknown",
            character_name=character_name
        )
        
    except OpenAIError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"OpenAI API error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Internal server error: {str(e)}")


@app.post("/api/chat/stream")
async def chat_completion_stream(request: ChatRequest):
    """
    Streaming chat completion with character persona support.
    Returns Server-Sent Events (SSE) for real-time response.
    """
    try:
        client = get_openai_client()
        
        # Determine system prompt (same logic as non-streaming)
        if request.system_prompt:
            system_prompt = request.system_prompt
        elif request.character:
            system_prompt = build_character_system_prompt(request.character)
        else:
            system_prompt = get_fallback_system_prompt()
        
        # Build messages array
        messages = [{"role": "system", "content": system_prompt}]
        for msg in request.messages:
            if msg.role != "system":
                messages.append({"role": msg.role, "content": msg.content})
        
        async def generate():
            try:
                stream = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=messages,
                    max_tokens=request.max_tokens,
                    temperature=request.temperature,
                    presence_penalty=0.6,
                    frequency_penalty=0.3,
                    stream=True,
                )
                
                for chunk in stream:
                    if chunk.choices[0].delta.content:
                        data = {"content": chunk.choices[0].delta.content, "is_complete": False}
                        yield f"data: {json.dumps(data)}\n\n"
                
                yield f"data: {json.dumps({'content': '', 'is_complete': True})}\n\n"
                
            except OpenAIError as e:
                yield f"data: {json.dumps({'error': str(e), 'is_complete': True})}\n\n"
        
        return StreamingResponse(
            generate(), 
            media_type="text/event-stream", 
            headers={"Cache-Control": "no-cache", "Connection": "keep-alive"}
        )
        
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to start stream: {str(e)}")


# ============================================
# IMAGE GENERATION ENDPOINTS
# ============================================

@app.get("/api/generate/models")
async def get_available_models():
    """Get list of available image generation models"""
    return {
        "models": [
            {"id": "flux-schnell", "name": "Flux Schnell", "description": "Fast, high-quality images", "speed": "fast"},
            {"id": "flux-dev", "name": "Flux Dev", "description": "Higher quality, slower", "speed": "medium"},
            {"id": "sdxl", "name": "SDXL", "description": "Stable Diffusion XL", "speed": "medium"},
            {"id": "sdxl-lightning", "name": "SDXL Lightning", "description": "Fast SDXL variant", "speed": "fast"},
        ]
    }


@app.post("/api/generate/image", response_model=ImageGenerationResponse)
async def generate_image(request: ImageGenerationRequest):
    """Generate image using Replicate models"""
    try:
        get_replicate_client()
        
        start_time = time.time()
        
        model_id = IMAGE_MODELS.get(request.model, IMAGE_MODELS["flux-schnell"])
        
        if request.model in ["flux-schnell", "flux-dev"]:
            input_params = {
                "prompt": request.prompt,
                "num_outputs": request.num_outputs,
                "aspect_ratio": _get_aspect_ratio(request.width, request.height),
                "output_format": "webp",
                "output_quality": 90,
            }
            if request.seed:
                input_params["seed"] = request.seed
        else:
            input_params = {
                "prompt": request.prompt,
                "negative_prompt": request.negative_prompt or "ugly, blurry, low quality, distorted",
                "width": request.width,
                "height": request.height,
                "num_outputs": request.num_outputs,
                "guidance_scale": request.guidance_scale,
                "num_inference_steps": request.num_inference_steps,
            }
            if request.seed:
                input_params["seed"] = request.seed
        
        output = replicate.run(model_id, input=input_params)
        
        images = []
        if isinstance(output, list):
            images = [str(url) for url in output]
        elif hasattr(output, '__iter__'):
            images = [str(url) for url in output]
        else:
            images = [str(output)]
        
        generation_time = time.time() - start_time
        
        return ImageGenerationResponse(
            images=images,
            generation_time=round(generation_time, 2),
            model=request.model,
            prompt=request.prompt
        )
        
    except replicate.exceptions.ReplicateError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Replicate API error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Image generation failed: {str(e)}")


@app.post("/api/generate/image/async")
async def generate_image_async(request: ImageGenerationRequest):
    """Start async image generation"""
    try:
        get_replicate_client()
        
        model_id = IMAGE_MODELS.get(request.model, IMAGE_MODELS["flux-schnell"])
        
        if request.model in ["flux-schnell", "flux-dev"]:
            input_params = {
                "prompt": request.prompt,
                "num_outputs": request.num_outputs,
                "aspect_ratio": _get_aspect_ratio(request.width, request.height),
                "output_format": "webp",
            }
        else:
            input_params = {
                "prompt": request.prompt,
                "negative_prompt": request.negative_prompt or "ugly, blurry, low quality",
                "width": request.width,
                "height": request.height,
                "num_outputs": request.num_outputs,
                "guidance_scale": request.guidance_scale,
            }
        
        model = replicate.models.get(model_id.split(":")[0] if ":" in model_id else model_id)
        version = model.latest_version if not ":" in model_id else None
        
        prediction = replicate.predictions.create(
            version=version or model_id.split(":")[1],
            input=input_params
        )
        
        return {
            "prediction_id": prediction.id,
            "status": prediction.status,
            "model": request.model
        }
        
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to start generation: {str(e)}")


@app.get("/api/generate/status/{prediction_id}", response_model=GenerationStatusResponse)
async def get_generation_status(prediction_id: str):
    """Get status of async image generation"""
    try:
        get_replicate_client()
        
        prediction = replicate.predictions.get(prediction_id)
        
        output = None
        if prediction.output:
            if isinstance(prediction.output, list):
                output = [str(url) for url in prediction.output]
            else:
                output = [str(prediction.output)]
        
        return GenerationStatusResponse(
            id=prediction.id,
            status=prediction.status,
            output=output,
            error=str(prediction.error) if prediction.error else None
        )
        
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to get status: {str(e)}")


def _get_aspect_ratio(width: int, height: int) -> str:
    """Convert dimensions to aspect ratio string for Flux models"""
    ratio = width / height
    
    if ratio >= 1.7:
        return "16:9"
    elif ratio >= 1.4:
        return "3:2"
    elif ratio >= 1.2:
        return "4:3"
    elif ratio >= 0.9:
        return "1:1"
    elif ratio >= 0.7:
        return "3:4"
    elif ratio >= 0.6:
        return "2:3"
    else:
        return "9:16"


# ============================================
# ERROR HANDLERS
# ============================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    return {"error": exc.detail, "status_code": exc.status_code, "timestamp": datetime.utcnow().isoformat()}


# ============================================
# RUN SERVER
# ============================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
